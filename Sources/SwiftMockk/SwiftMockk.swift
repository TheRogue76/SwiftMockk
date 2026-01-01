// swiftlint:disable force_cast
// SwiftMockk - A Swift mocking library inspired by Kotlin's mockk
//
// To generate mocks, mark your protocols with `// swiftmockk:generate` comment
// and add the SwiftMockkGeneratorPlugin to your test target.
//
// Example:
// ```swift
// // In your main target (no SwiftMockk import needed):
// // swiftmockk:generate
// protocol UserService {
//     func fetchUser(id: String) -> User
// }
//
// // In your test target Package.swift:
// .testTarget(
//     name: "MyAppTests",
//     dependencies: ["MyApp", "SwiftMockk"],
//     plugins: [.plugin(name: "SwiftMockkGeneratorPlugin", package: "SwiftMockk")]
// )
// ```

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

    // For complex types (arrays, optionals, Result, etc.), check if we're in stubbing/verifying mode
    let mode = RecordingContext.shared.getCurrentMode()
    if mode == .stubbing || mode == .verifying {
        // Return uninitialized memory - safe because value is never actually used in DSL
        let size = MemoryLayout<T>.size
        let alignment = MemoryLayout<T>.alignment
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: alignment)
        defer { ptr.deallocate() }
        return ptr.load(as: T.self)
    }

    // In normal/relaxed mode, we can't safely create dummy values for complex types
    throw MockError.noStub("Cannot create dummy value for type \(T.self)")
}

/// Internal helper that wraps stub lookup with mode checking
public func _mockGetStub<T>(for call: MethodCall, mockMode: MockMode = .strict) throws(any Error) -> T {
    let mode = RecordingContext.shared.getCurrentMode()
    if mode == .stubbing || mode == .verifying {
        // Try to create a dummy value for primitive types
        // For complex types, this will throw and be caught by DSL functions
        return try _mockDummyValue()
    }

    do {
        return try StubbingRegistry.shared.getStub(for: call)
    } catch MockError.noStub {
        // If in relaxed mode, return dummy value instead of throwing
        if mockMode == .relaxed {
            return try _mockDummyValue()
        }
        throw MockError.noStub(call.name)
    }
}

/// Internal helper for async stub lookup
public func _mockGetAsyncStub<T>(for call: MethodCall, mockMode: MockMode = .strict) async throws(any Error) -> T {
    let mode = RecordingContext.shared.getCurrentMode()
    if mode == .stubbing || mode == .verifying {
        // Try to create a dummy value for primitive types
        // For complex types, this will throw and be caught by DSL functions
        return try _mockDummyValue()
    }

    do {
        return try await StubbingRegistry.shared.getAsyncStub(for: call)
    } catch MockError.noStub {
        // If in relaxed mode, return dummy value instead of throwing
        if mockMode == .relaxed {
            return try _mockDummyValue()
        }
        throw MockError.noStub(call.name)
    }
}

/// Internal helper for void throwing methods
public func _mockExecuteThrowingStub(for call: MethodCall) throws(any Error) {
    let mode = RecordingContext.shared.getCurrentMode()
    if mode == .stubbing || mode == .verifying {
        return // Just return, don't throw for void methods
    }
    try StubbingRegistry.shared.executeThrowingStub(for: call)
}

// MARK: - Typed Throws Helpers

/// Internal helper for typed throws methods - uses fatalError for missing stubs
public func _mockGetTypedStub<T, E: Error>(
    for call: MethodCall, mockMode: MockMode = .strict, errorType: E.Type
) throws(E) -> T {
    let mode = RecordingContext.shared.getCurrentMode()
    if mode == .stubbing || mode == .verifying {
        // Return uninitialized memory - safe because value is never used in DSL
        let size = MemoryLayout<T>.size
        let alignment = MemoryLayout<T>.alignment
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: alignment)
        defer { ptr.deallocate() }
        return ptr.load(as: T.self)
    }

    do {
        let result: T = try StubbingRegistry.shared.getStub(for: call)
        return result
    } catch MockError.noStub {
        // Typed throws methods cannot throw MockError, so fatal error instead
        fatalError(
            "No stub registered for typed throws method '\(call.name)'. " +
            "Typed throws methods must be stubbed. Use every { ... } to stub this method."
        )
    } catch {
        // Cast and rethrow user errors
        throw error as! E
    }
}

/// Internal helper for async typed throws methods
public func _mockGetTypedAsyncStub<T, E: Error>(
    for call: MethodCall, mockMode: MockMode = .strict, errorType: E.Type
) async throws(E) -> T {
    let mode = RecordingContext.shared.getCurrentMode()
    if mode == .stubbing || mode == .verifying {
        // Return uninitialized memory - safe because value is never used in DSL
        let size = MemoryLayout<T>.size
        let alignment = MemoryLayout<T>.alignment
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: alignment)
        defer { ptr.deallocate() }
        return ptr.load(as: T.self)
    }

    do {
        let result: T = try await StubbingRegistry.shared.getAsyncStub(for: call)
        return result
    } catch MockError.noStub {
        fatalError(
            "No stub registered for typed throws method '\(call.name)'. " +
            "Typed throws methods must be stubbed. Use every { ... } to stub this method."
        )
    } catch {
        throw error as! E
    }
}

/// Internal helper for void typed throws methods
public func _mockExecuteTypedThrowingStub<E: Error>(for call: MethodCall, errorType: E.Type) throws(E) {
    let mode = RecordingContext.shared.getCurrentMode()
    if mode == .stubbing || mode == .verifying {
        return
    }

    do {
        try StubbingRegistry.shared.executeThrowingStub(for: call)
    } catch MockError.noStub {
        fatalError(
            "No stub registered for typed throws method '\(call.name)'. " +
            "Typed throws methods must be stubbed. Use every { ... } to stub this method."
        )
    } catch {
        throw error as! E
    }
}

// MARK: - mockk Factory Functions

/// Creates a mock instance using Kotlin mockk-style API.
///
/// This function looks up a registered mock factory for the given protocol type
/// and creates a new mock instance. Mocks are automatically registered when the
/// generated mock code is loaded.
///
/// Example:
/// ```swift
/// let mock = mockk(UserService.self)
/// let relaxedMock = mockk(UserService.self, mode: .relaxed)
///
/// await every { try await mock.fetchUser(id: "123") }.returns(testUser)
/// ```
///
/// - Parameters:
///   - protocolType: The protocol type to create a mock for (e.g., `UserService.self`)
///   - mode: The mock mode (strict or relaxed). Defaults to `.strict`
/// - Returns: A mock instance that conforms to the protocol
/// - Note: This function will crash if no mock is registered for the protocol.
///         Use `tryMockk()` for error handling instead.
/// - Important: Generic protocols (those with associated types or type parameters)
///              cannot use `mockk()`. Use direct instantiation instead:
///              `MockRepository<User>()`.
public func mockk<T>(_ protocolType: T.Type, mode: MockMode = .strict) -> T {
    do {
        return try MockRegistry.shared.create(protocolType, mode: mode)
    } catch {
        fatalError("\(error)")
    }
}

/// Creates a mock instance with error handling.
///
/// This is the throwing variant of `mockk()` that returns an error instead of
/// crashing when no mock is registered.
///
/// Example:
/// ```swift
/// do {
///     let mock = try tryMockk(UserService.self)
/// } catch MockRegistryError.notRegistered(let name) {
///     print("No mock registered for \(name)")
/// }
/// ```
///
/// - Parameters:
///   - protocolType: The protocol type to create a mock for
///   - mode: The mock mode (strict or relaxed). Defaults to `.strict`
/// - Returns: A mock instance that conforms to the protocol
/// - Throws: `MockRegistryError.notRegistered` if no mock is registered,
///           `MockRegistryError.typeMismatch` if the mock type doesn't match
public func tryMockk<T>(_ protocolType: T.Type, mode: MockMode = .strict) throws -> T {
    try MockRegistry.shared.create(protocolType, mode: mode)
}
