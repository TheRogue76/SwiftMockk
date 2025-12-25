import Foundation

/// Protocol that marks a type as mockable
/// Generated mock classes conform to this protocol to provide access to recording infrastructure
public protocol Mockable {
    var _mockId: String { get }
    var _recorder: CallRecorder { get }
}
