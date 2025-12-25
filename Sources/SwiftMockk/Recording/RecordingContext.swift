import Foundation

/// Global context for managing recording modes during stubbing and verification
public final class RecordingContext: @unchecked Sendable {
    /// Shared instance
    public static let shared = RecordingContext()

    /// Current recording mode
    private var mode: Mode = .normal

    /// The last call captured during stubbing or verification
    private var _lastCapturedCall: MethodCall?

    /// Optional callback for capturing calls (used in verifyOrder/verifySequence)
    private var _onCapture: ((MethodCall) -> Void)?

    private let lock = NSLock()

    private init() {}

    /// Recording modes
    public enum Mode: Sendable, Equatable {
        case normal
        case stubbing
        case verifying
    }

    /// Enter a recording mode
    public func enterMode(_ newMode: Mode) {
        lock.lock()
        defer { lock.unlock() }
        mode = newMode
        _lastCapturedCall = nil
    }

    /// Exit the current mode and return to normal
    public func exitMode() {
        lock.lock()
        defer { lock.unlock() }
        mode = .normal
        _onCapture = nil
    }

    /// Get the current mode
    public func getCurrentMode() -> Mode {
        lock.lock()
        defer { lock.unlock() }
        return mode
    }

    /// Record a call (called by generated mock methods)
    public func record(_ call: MethodCall) {
        lock.lock()
        defer { lock.unlock() }
        _lastCapturedCall = call
        _onCapture?(call)
    }

    /// Get the last captured call
    public func getLastCapturedCall() -> MethodCall? {
        lock.lock()
        defer { lock.unlock() }
        return _lastCapturedCall
    }

    /// Set the capture callback
    public func setOnCapture(_ callback: @escaping (MethodCall) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        _onCapture = callback
    }

    /// Clear the capture callback
    public func clearOnCapture() {
        lock.lock()
        defer { lock.unlock() }
        _onCapture = nil
    }
}
