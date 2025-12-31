/// Builder for configuring stub behavior
public class Stubbing {
    let call: MethodCall

    init(call: MethodCall) {
        self.call = call
    }

    /// Configure the stub to return a specific value
    public func returns<T>(_ value: T) {
        StubbingRegistry.shared.registerStub(
            for: call,
            behavior: .value(value)
        )
    }

    /// Configure the stub to throw an error
    public func `throws`(_ error: Error) {
        StubbingRegistry.shared.registerStub(
            for: call,
            behavior: .error(error)
        )
    }

    /// Configure the stub with a custom closure
    public func answers(_ block: @escaping ([Any]) -> Any) {
        StubbingRegistry.shared.registerStub(
            for: call,
            behavior: .closure(block)
        )
    }

    /// Configure the stub to return a success Result
    /// - Parameters:
    ///   - value: The success value
    ///   - failureType: The failure error type (required for type inference)
    public func returnsSuccess<Success, Failure: Error>(_ value: Success, failureType: Failure.Type) {
        StubbingRegistry.shared.registerStub(
            for: call,
            behavior: .value(Result<Success, Failure>.success(value))
        )
    }

    /// Configure the stub to return a failure Result
    /// - Parameters:
    ///   - error: The failure error
    ///   - successType: The success value type (required for type inference)
    public func returnsFailure<Success, Failure: Error>(_ error: Failure, successType: Success.Type) {
        StubbingRegistry.shared.registerStub(
            for: call,
            behavior: .value(Result<Success, Failure>.failure(error))
        )
    }
}
