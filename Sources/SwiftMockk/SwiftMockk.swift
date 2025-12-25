// SwiftMockk - A Swift mocking library inspired by Kotlin's mockk

/// Macro that generates a mock implementation for a protocol
///
/// Apply this macro to a protocol to automatically generate a `Mock{ProtocolName}` class
/// that implements the protocol and provides stubbing and verification capabilities.
///
/// Example:
/// ```swift
/// @Mockable
/// protocol UserService {
///     func fetchUser(id: String) -> User
/// }
/// // Generates: class MockUserService: UserService { ... }
/// ```
@attached(peer, names: prefixed(Mock))
public macro Mockable() = #externalMacro(module: "SwiftMockkMacros", type: "MockableMacro")
