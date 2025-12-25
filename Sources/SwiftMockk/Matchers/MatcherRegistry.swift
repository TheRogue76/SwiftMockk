import Foundation

/// Thread-safe storage for argument matchers
public final class MatcherRegistry: @unchecked Sendable {
    public static let shared = MatcherRegistry()

    private let lock = NSLock()
    private var matchers: [any ArgumentMatcher] = []

    private init() {}

    /// Register a matcher
    public func register(_ matcher: any ArgumentMatcher) {
        lock.lock()
        defer { lock.unlock() }
        matchers.append(matcher)
    }

    /// Get all registered matchers and clear
    public func extractMatchers() -> [any ArgumentMatcher] {
        lock.lock()
        defer { lock.unlock() }
        let current = matchers
        matchers.removeAll()
        return current
    }

    /// Check if any matchers are registered
    public func hasMatchers() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !matchers.isEmpty
    }

    /// Clear all matchers
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        matchers.removeAll()
    }
}
