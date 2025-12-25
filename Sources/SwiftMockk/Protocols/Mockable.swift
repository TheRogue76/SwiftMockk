import Foundation

/// Mock behavior mode
public enum MockMode {
    /// Strict mode: unstubbed methods throw errors
    case strict
    /// Relaxed mode: unstubbed methods return default values
    case relaxed
}

/// Protocol that marks a type as mockable
/// Generated mock classes conform to this protocol to provide access to recording infrastructure
public protocol Mockable {
    var _mockId: String { get }
    var _recorder: CallRecorder { get }
    var _mockMode: MockMode { get set }
}
