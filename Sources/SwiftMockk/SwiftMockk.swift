// swiftlint:disable force_cast
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

    // Check if T is Result type - in relaxed mode, we can't create a safe dummy value
    // But in stubbing/verifying mode, we need to return something (it won't be used)
    let typeName = String(describing: T.self)
    let mode = RecordingContext.shared.getCurrentMode()
    if typeName.starts(with: "Result<") {
        if mode == .stubbing || mode == .verifying {
            // Return uninitialized memory - safe because value is never actually used in DSL
            let size = MemoryLayout<T>.size
            let alignment = MemoryLayout<T>.alignment
            let ptr = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: alignment)
            defer { ptr.deallocate() }
            return ptr.load(as: T.self)
        }
        throw MockError.noStub("Cannot create dummy value for Result type in relaxed mode")
    }

    // For other types, throw error - can't safely create dummy values
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
public func _mockGetTypedStub<T, E: Error>(for call: MethodCall, mockMode: MockMode = .strict, errorType: E.Type) throws(E) -> T {
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
        fatalError("No stub registered for typed throws method '\(call.name)'. Typed throws methods must be stubbed. Use every { ... } to stub this method.")
    } catch {
        // Cast and rethrow user errors
        throw error as! E
    }
}

/// Internal helper for async typed throws methods
public func _mockGetTypedAsyncStub<T, E: Error>(for call: MethodCall, mockMode: MockMode = .strict, errorType: E.Type) async throws(E) -> T {
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
        fatalError("No stub registered for typed throws method '\(call.name)'. Typed throws methods must be stubbed. Use every { ... } to stub this method.")
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
        fatalError("No stub registered for typed throws method '\(call.name)'. Typed throws methods must be stubbed. Use every { ... } to stub this method.")
    } catch {
        throw error as! E
    }
}
