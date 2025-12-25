/// Configure stub behavior for a mock method call
///
/// Example:
/// ```swift
/// await every { await mock.fetchUser(id: "123") } returns User(id: "123")
/// ```
@discardableResult
public func every(_ block: () async throws -> Any?) async rethrows -> Stubbing {
    // Execute the closure in stubbing mode and capture the call within the same scope
    let call = try await RecordingContext.shared.withMode(.stubbing) {
        do {
            _ = try await block()
        } catch MockError.noStub {
            // Expected - we're in stubbing mode, no stub exists yet or can't create dummy value
            // This is fine, we just need the call to be recorded
        } catch {
            // Re-throw other errors
            throw error
        }

        // Get the captured call before exiting the task-local scope
        guard let capturedCall = RecordingContext.shared.getLastCapturedCall() else {
            fatalError("No call was captured during stubbing")
        }

        return capturedCall
    }

    return Stubbing(call: call)
}
