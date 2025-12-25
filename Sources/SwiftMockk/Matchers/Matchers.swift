/// Matches any value of the specified type
///
/// Example:
/// ```swift
/// await every { await mock.fetchUser(id: any()) } await returns(User())
/// ```
public func any<T>() -> T {
    MatcherRegistry.shared.register(AnyMatcher())
    // Return a zero-initialized value
    // Note: This creates uninitialized memory which is unsafe but necessary for the DSL
    let size = MemoryLayout<T>.size
    let alignment = MemoryLayout<T>.alignment
    let pointer = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: alignment)
    pointer.initializeMemory(as: UInt8.self, repeating: 0, count: size)
    let value = pointer.load(as: T.self)
    pointer.deallocate()
    return value
}

/// Matches a specific value using equality
///
/// Example:
/// ```swift
/// await every { await mock.fetchUser(id: eq("123")) } await returns(User())
/// ```
public func eq<T: Equatable>(_ value: T) -> T {
    MatcherRegistry.shared.register(EqualityMatcher(expected: value))
    return value
}

/// Matches using a custom predicate
///
/// Example:
/// ```swift
/// await every { await mock.fetchUsers(minAge: match { $0 >= 18 }) } await returns([])
/// ```
public func match<T>(_ predicate: @escaping (T) -> Bool) -> T {
    MatcherRegistry.shared.register(PredicateMatcher(predicate: predicate))
    // Return a zero-initialized value
    let size = MemoryLayout<T>.size
    let alignment = MemoryLayout<T>.alignment
    let pointer = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: alignment)
    pointer.initializeMemory(as: UInt8.self, repeating: 0, count: size)
    let value = pointer.load(as: T.self)
    pointer.deallocate()
    return value
}

// MARK: - Matcher Implementations

struct AnyMatcher: ArgumentMatcher {
    func matches(_ value: Any) -> Bool {
        return true
    }
}

struct EqualityMatcher<T: Equatable>: ArgumentMatcher, @unchecked Sendable {
    let expected: T

    func matches(_ value: Any) -> Bool {
        guard let actual = value as? T else { return false }
        return actual == expected
    }
}

struct PredicateMatcher<T>: ArgumentMatcher, @unchecked Sendable {
    let predicate: (T) -> Bool

    func matches(_ value: Any) -> Bool {
        guard let actual = value as? T else { return false }
        return predicate(actual)
    }
}
