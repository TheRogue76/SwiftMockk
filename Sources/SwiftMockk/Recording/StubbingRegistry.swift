import Foundation

/// Registry that stores stubs for mock method calls
public final class StubbingRegistry: @unchecked Sendable {
    /// Shared instance
    public static let shared = StubbingRegistry()

    /// Storage for stubs, keyed by mock ID and method name
    private var stubs: [String: [String: [Stub]]] = [:]
    private let lock = NSLock()

    private init() {}

    /// A stub defines the behavior for a method call
    public enum StubBehavior: @unchecked Sendable {
        case value(Any)
        case error(Error)
        case closure(([Any]) -> Any)
    }

    private struct Stub {
        let pattern: MethodCall
        let behavior: StubBehavior
    }

    /// Register a stub for a method call pattern
    public func registerStub(for call: MethodCall, behavior: StubBehavior) {
        lock.lock()
        defer { lock.unlock() }

        let stub = Stub(pattern: call, behavior: behavior)
        if stubs[call.mockId] == nil {
            stubs[call.mockId] = [:]
        }
        if stubs[call.mockId]![call.name] == nil {
            stubs[call.mockId]![call.name] = []
        }
        // Insert at the beginning so newer stubs take precedence
        stubs[call.mockId]![call.name]!.insert(stub, at: 0)
    }

    /// Get a stub for a synchronous method call
    public func getStub<T>(for call: MethodCall) throws -> T {
        guard let stub = findStub(for: call) else {
            throw MockError.noStub(call.name)
        }

        switch stub.behavior {
        case .value(let value):
            guard let typedValue = value as? T else {
                throw MockError.typeMismatch(expected: T.self, got: type(of: value))
            }
            return typedValue
        case .error(let error):
            throw error
        case .closure(let block):
            let result = block(call.args)
            guard let typedResult = result as? T else {
                throw MockError.typeMismatch(expected: T.self, got: type(of: result))
            }
            return typedResult
        }
    }

    /// Get a stub for an async method call
    public func getAsyncStub<T>(for call: MethodCall) async throws -> T {
        // For now, async stubs work the same as sync stubs
        // In the future, we could support async closures
        return try getStub(for: call)
    }

    /// Execute a throwing stub (for methods that return Void)
    public func executeThrowingStub(for call: MethodCall) throws {
        guard let stub = findStub(for: call) else {
            // For void methods, if no stub is registered, just return
            return
        }

        switch stub.behavior {
        case .value:
            return
        case .error(let error):
            throw error
        case .closure(let block):
            _ = block(call.args)
        }
    }

    /// Find a matching stub
    private func findStub(for call: MethodCall) -> Stub? {
        lock.lock()
        defer { lock.unlock() }

        guard let mockStubs = stubs[call.mockId],
              let methodStubs = mockStubs[call.name] else { return nil }

        // Find the first stub whose pattern matches the call
        return methodStubs.first { $0.pattern.matches(call) }
    }

    /// Clear all stubs
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        stubs.removeAll()
    }
}

/// Errors that can occur during mocking
public enum MockError: Error, CustomStringConvertible {
    case noStub(String)
    case typeMismatch(expected: Any.Type, got: Any.Type)
    case notInRecordingMode

    public var description: String {
        switch self {
        case .noStub(let methodName):
            return "No stub registered for method '\(methodName)'. Use every { ... } to stub this method."
        case .typeMismatch(let expected, let got):
            return "Type mismatch: expected \(expected) but got \(got)"
        case .notInRecordingMode:
            return "Not in recording mode. This should only be called from every { } or verify { } blocks."
        }
    }
}
