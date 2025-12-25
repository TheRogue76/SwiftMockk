import Foundation

/// Thread-safe storage for argument matchers, isolated per task
public final class MatcherRegistry: @unchecked Sendable {
    public static let shared = MatcherRegistry()

    private let lock = NSLock()
    // Store matchers per task using ObjectIdentifier of the unstructured Task
    private var matchersByTask: [ObjectIdentifier: [any ArgumentMatcher]] = [:]

    private init() {}

    /// Get the current task identifier
    private func getCurrentTaskId() -> ObjectIdentifier {
        // Use the current thread as a proxy for task identity
        // This works because each test task runs on its own execution context
        return ObjectIdentifier(Thread.current)
    }

    /// Register a matcher for the current task
    public func register(_ matcher: any ArgumentMatcher) {
        lock.lock()
        defer { lock.unlock() }

        let taskId = getCurrentTaskId()
        if matchersByTask[taskId] == nil {
            matchersByTask[taskId] = []
        }
        matchersByTask[taskId]!.append(matcher)
    }

    /// Get all registered matchers for the current task and clear them
    public func extractMatchers() -> [any ArgumentMatcher] {
        lock.lock()
        defer { lock.unlock() }

        let taskId = getCurrentTaskId()
        let current = matchersByTask[taskId] ?? []
        matchersByTask[taskId] = nil
        return current
    }

    /// Check if any matchers are registered for the current task
    public func hasMatchers() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let taskId = getCurrentTaskId()
        return !(matchersByTask[taskId]?.isEmpty ?? true)
    }

    /// Clear all matchers for the current task
    public func clear() {
        lock.lock()
        defer { lock.unlock() }

        let taskId = getCurrentTaskId()
        matchersByTask[taskId] = nil
    }
}
