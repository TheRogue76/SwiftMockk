/// Configure stub behavior for a mock method call
///
/// Example:
/// ```swift
/// await every { await mock.fetchUser(id: "123") } returns User(id: "123")
/// ```
@discardableResult
public func every(_ block: () async throws -> Any?) async rethrows -> Stubbing {
    // Enter stubbing mode
    await RecordingContext.shared.enterMode(.stubbing)

    // Execute the closure - this will trigger the mock method and capture the call
    _ = try await block()

    // Get the captured call
    guard let call = await RecordingContext.shared.getLastCapturedCall() else {
        await RecordingContext.shared.exitMode()
        fatalError("No call was captured during stubbing")
    }

    await RecordingContext.shared.exitMode()

    return Stubbing(call: call)
}
