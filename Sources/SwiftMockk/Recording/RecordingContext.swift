import Foundation

/// Mutable container for task-local state
private final class TaskLocalState: @unchecked Sendable {
    private let lock = NSLock()
    private var _lastCall: MethodCall?
    private var _onCapture: (@Sendable (MethodCall) -> Void)?

    var lastCall: MethodCall? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _lastCall
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _lastCall = newValue
        }
    }

    var onCapture: (@Sendable (MethodCall) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _onCapture
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _onCapture = newValue
        }
    }
}

/// Context for managing recording modes during stubbing and verification
/// Uses task-local storage for proper test isolation
public final class RecordingContext: @unchecked Sendable {
    /// Shared instance (only for accessing task-local values)
    public static let shared = RecordingContext()

    private init() {}

    /// Recording modes
    public enum Mode: Sendable, Equatable {
        case normal
        case stubbing
        case verifying
    }

    /// Task-local storage for recording mode
    @TaskLocal
    private static var mode: Mode = .normal

    /// Task-local storage for mutable state
    @TaskLocal
    private static var state: TaskLocalState?

    /// Enter a recording mode within the current task
    public func withMode<T>(_ newMode: Mode, operation: () async throws -> T) async rethrows -> T {
        let existingState = Self.state
        let state = existingState ?? TaskLocalState()

        return try await Self.$mode.withValue(newMode) {
            if existingState != nil {
                // Reuse existing state (e.g., when nested inside withOnCapture)
                return try await operation()
            } else {
                // Create new state context
                return try await Self.$state.withValue(state) {
                    try await operation()
                }
            }
        }
    }

    /// Get the current mode for this task
    public func getCurrentMode() -> Mode {
        Self.mode
    }

    /// Record a call (called by generated mock methods)
    public func record(_ call: MethodCall) {
        Self.state?.lastCall = call
        Self.state?.onCapture?(call)
    }

    /// Get the last captured call for this task
    public func getLastCapturedCall() -> MethodCall? {
        Self.state?.lastCall
    }

    /// Execute operation with a capture callback
    public func withOnCapture<T>(_ callback: @escaping @Sendable (MethodCall) -> Void, operation: () async throws -> T) async rethrows -> T {
        let existingState = Self.state
        let state = existingState ?? TaskLocalState()
        state.onCapture = callback

        if existingState != nil {
            // Already in a task-local context, just set the callback
            defer { state.onCapture = nil }
            return try await operation()
        } else {
            // Create new task-local context
            return try await Self.$state.withValue(state) {
                defer { state.onCapture = nil }
                return try await operation()
            }
        }
    }
}
