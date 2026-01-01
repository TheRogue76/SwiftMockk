import Foundation

// MARK: - MockFactory

/// Type-erased factory for creating mock instances
public struct MockFactory: @unchecked Sendable {
    private let _create: (MockMode) -> any Mockable

    /// Creates a mock factory from a typed closure
    /// - Parameter factory: A closure that creates a mock instance with the given mode
    public init<T: Mockable>(_ factory: @escaping (MockMode) -> T) {
        self._create = { mode in factory(mode) }
    }

    /// Creates a mock instance with the specified mode
    /// - Parameter mode: The mock mode (strict or relaxed)
    /// - Returns: A mock instance
    public func create(mode: MockMode) -> any Mockable {
        _create(mode)
    }
}

// MARK: - MockRegistryError

/// Errors that can occur during mock registry operations
public enum MockRegistryError: Error, CustomStringConvertible {
    /// No mock is registered for the given protocol type
    case notRegistered(String)
    /// The mock type doesn't match the expected protocol type
    case typeMismatch(expected: String, got: String)

    public var description: String {
        switch self {
        case .notRegistered(let protocolName):
            return """
            No mock registered for protocol '\(protocolName)'.
            Ensure the protocol is marked with '// swiftmockk:generate' and the mock generator plugin is running.
            """
        case .typeMismatch(let expected, let got):
            return "Mock type mismatch: expected '\(expected)' but got '\(got)'"
        }
    }
}

// MARK: - MockRegistry

/// Global registry mapping protocol types to their mock factories.
///
/// Generated mocks automatically register themselves with this registry,
/// enabling the `mockk()` factory function to create mock instances by protocol type.
///
/// Example:
/// ```swift
/// // Registration happens automatically in generated code
/// MockRegistry.shared.register(UserService.self) { mode in
///     MockUserService(mode: mode)
/// }
///
/// // Later, create mocks via the registry
/// let mock = try MockRegistry.shared.create(UserService.self, mode: .strict)
/// ```
public final class MockRegistry: @unchecked Sendable {
    /// Shared singleton instance
    public static let shared = MockRegistry()

    /// Storage using ObjectIdentifier of the protocol metatype as key
    private var factories: [ObjectIdentifier: MockFactory] = [:]
    private let lock = NSLock()

    private init() {}

    /// Register a mock factory for a protocol type.
    ///
    /// This method is typically called automatically by generated mock classes
    /// during static initialization.
    ///
    /// - Parameters:
    ///   - protocolType: The protocol type (e.g., `UserService.self`)
    ///   - factory: A closure that creates mock instances
    public func register<Protocol, Mock: Mockable>(
        _ protocolType: Protocol.Type,
        factory: @escaping (MockMode) -> Mock
    ) {
        lock.lock()
        defer { lock.unlock() }

        let key = ObjectIdentifier(protocolType)
        factories[key] = MockFactory(factory)
    }

    /// Create a mock instance for the given protocol type.
    ///
    /// - Parameters:
    ///   - protocolType: The protocol type to mock
    ///   - mode: The mock mode (strict or relaxed)
    /// - Returns: A mock instance conforming to the protocol
    /// - Throws: `MockRegistryError.notRegistered` if no mock is registered,
    ///           `MockRegistryError.typeMismatch` if the mock doesn't conform to the protocol
    public func create<T>(_ protocolType: T.Type, mode: MockMode) throws -> T {
        lock.lock()
        let factory = factories[ObjectIdentifier(protocolType)]
        lock.unlock()

        guard let factory = factory else {
            throw MockRegistryError.notRegistered(String(describing: protocolType))
        }

        let mock = factory.create(mode: mode)

        guard let typedMock = mock as? T else {
            throw MockRegistryError.typeMismatch(
                expected: String(describing: T.self),
                got: String(describing: type(of: mock))
            )
        }

        return typedMock
    }

    /// Check if a mock is registered for the given protocol type.
    ///
    /// - Parameter protocolType: The protocol type to check
    /// - Returns: `true` if a mock factory is registered, `false` otherwise
    public func isRegistered<T>(_ protocolType: T.Type) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return factories[ObjectIdentifier(protocolType)] != nil
    }

    /// Clear all registered mocks.
    ///
    /// This is primarily useful for testing the registry itself.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        factories.removeAll()
    }
}
