import Foundation

/// Records method calls made on a mock
public actor CallRecorder {
    /// Shared registry
    private static let registry = CallRecorderRegistry()

    /// All recorded calls (in normal mode)
    private var recordedCalls: [MethodCall] = []

    fileprivate init() {}

    /// Get shared recorder for a mock ID
    public static func shared(for mockId: String) -> CallRecorder {
        registry.getRecorder(for: mockId)
    }

    /// Record a method call
    public func record(_ call: MethodCall) async {
        let mode = await RecordingContext.shared.getCurrentMode()

        switch mode {
        case .normal:
            // Normal mode: record the call for later verification
            recordedCalls.append(call)
        case .stubbing, .verifying:
            // Stubbing/Verifying mode: just capture for pattern matching
            await RecordingContext.shared.record(call)
        }
    }

    /// Find all calls matching a pattern
    public func findMatching(_ pattern: MethodCall) -> [MethodCall] {
        return recordedCalls.filter { pattern.matches($0) }
    }

    /// Get all recorded calls
    public func getAllCalls() -> [MethodCall] {
        return recordedCalls
    }

    /// Clear all recorded calls
    public func reset() {
        recordedCalls.removeAll()
    }

    /// Get the number of recorded calls
    public func count() -> Int {
        return recordedCalls.count
    }
}

/// Registry for call recorders
private final class CallRecorderRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var recorders: [String: CallRecorder] = [:]

    func getRecorder(for mockId: String) -> CallRecorder {
        lock.lock()
        defer { lock.unlock() }

        if let recorder = recorders[mockId] {
            return recorder
        }
        let recorder = CallRecorder()
        recorders[mockId] = recorder
        return recorder
    }
}
