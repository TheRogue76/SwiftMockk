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

/// Internal dummy value provider - only handles safe primitive types
private func _mockDummyValue<T>() throws -> T {
    // Handle common primitive types safely
    if T.self == Int.self { return 0 as! T }
    if T.self == String.self { return "" as! T }
    if T.self == Bool.self { return false as! T }
    if T.self == Double.self { return 0.0 as! T }
    if T.self == Float.self { return Float(0.0) as! T }
    if T.self == Int8.self { return Int8(0) as! T }
    if T.self == Int16.self { return Int16(0) as! T }
    if T.self == Int32.self { return Int32(0) as! T }
    if T.self == Int64.self { return Int64(0) as! T }
    if T.self == UInt.self { return UInt(0) as! T }
    if T.self == UInt8.self { return UInt8(0) as! T }
    if T.self == UInt16.self { return UInt16(0) as! T }
    if T.self == UInt32.self { return UInt32(0) as! T }
    if T.self == UInt64.self { return UInt64(0) as! T }

    // For zero-sized types (like Void or empty structs)
    if MemoryLayout<T>.size == 0 {
        return unsafeBitCast((), to: T.self)
    }

    // For other types, throw error - can't safely create dummy values
    throw MockError.noStub("Cannot create dummy value for type \(T.self)")
}

/// Internal helper that wraps stub lookup with mode checking
public func _mockGetStub<T>(for call: MethodCall) throws -> T {
    let mode = RecordingContext.shared.getCurrentMode()
    if mode == .stubbing || mode == .verifying {
        // Try to create a dummy value for primitive types
        // For complex types, this will throw and be caught by DSL functions
        return try _mockDummyValue()
    }
    return try StubbingRegistry.shared.getStub(for: call)
}

/// Internal helper for async stub lookup
public func _mockGetAsyncStub<T>(for call: MethodCall) async throws -> T {
    let mode = RecordingContext.shared.getCurrentMode()
    if mode == .stubbing || mode == .verifying {
        // Try to create a dummy value for primitive types
        // For complex types, this will throw and be caught by DSL functions
        return try _mockDummyValue()
    }
    return try await StubbingRegistry.shared.getAsyncStub(for: call)
}

/// Internal helper for void throwing methods
public func _mockExecuteThrowingStub(for call: MethodCall) throws {
    let mode = RecordingContext.shared.getCurrentMode()
    if mode == .stubbing || mode == .verifying {
        return // Just return, don't throw for void methods
    }
    try StubbingRegistry.shared.executeThrowingStub(for: call)
}
