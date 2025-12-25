import Testing

/// Verification modes for checking call counts
public enum VerificationMode {
    case exactly(Int)
    case atLeast(Int)
    case atMost(Int)
    case atLeastOnce

    func matches(_ count: Int) -> Bool {
        switch self {
        case .exactly(let n): return count == n
        case .atLeast(let n): return count >= n
        case .atMost(let n): return count <= n
        case .atLeastOnce: return count >= 1
        }
    }

    var description: String {
        switch self {
        case .exactly(let n): return "exactly \(n) time(s)"
        case .atLeast(let n): return "at least \(n) time(s)"
        case .atMost(let n): return "at most \(n) time(s)"
        case .atLeastOnce: return "at least once"
        }
    }
}

/// Verify that a mock method was called
///
/// Example:
/// ```swift
/// await verify { await mock.fetchUser(id: "123") }
/// await verify(times: .exactly(2)) { await mock.fetchUser(id: any()) }
/// ```
public func verify(
    times: VerificationMode = .atLeastOnce,
    _ block: () async throws -> Any?
) async rethrows {
    // Enter verifying mode
    await RecordingContext.shared.enterMode(.verifying)

    // Execute the closure - this will capture the call pattern
    _ = try await block()

    // Get the captured call pattern
    guard let pattern = await RecordingContext.shared.getLastCapturedCall() else {
        await RecordingContext.shared.exitMode()
        Issue.record(Comment(rawValue: "No call was captured during verification"))
        return
    }

    await RecordingContext.shared.exitMode()

    // Find matching calls from the recorder
    // Note: We need to get the recorder from somewhere - for now use a global approach
    // In practice, the pattern.mockId tells us which mock to check
    let actualCalls = await CallRecorder.shared(for: pattern.mockId).findMatching(pattern)

    // Check if the count matches
    guard times.matches(actualCalls.count) else {
        let message = "Expected call '\(pattern.name)' \(times.description), but was called \(actualCalls.count) time(s)"
        Issue.record(Comment(rawValue: message))
        return
    }
}

/// Verify calls happened in a specific order
///
/// Example:
/// ```swift
/// await verifyOrder {
///     await mock.fetchUser(id: "1")
///     await mock.updateUser(user: any())
/// }
/// ```
public func verifyOrder(_ block: () async throws -> Void) async rethrows {
    var expectedCalls: [MethodCall] = []

    await RecordingContext.shared.enterMode(.verifying)
    await RecordingContext.shared.setOnCapture { call in
        expectedCalls.append(call)
    }

    try await block()

    await RecordingContext.shared.clearOnCapture()
    await RecordingContext.shared.exitMode()

    // Verify the calls appear in order (but not necessarily consecutively)
    // This requires access to all recorded calls
    // For MVP, we'll skip this implementation detail
    Issue.record(Comment(rawValue: "verifyOrder is not yet fully implemented"))
}

/// Verify exact sequence of calls
///
/// Example:
/// ```swift
/// await verifySequence {
///     await mock.login()
///     await mock.fetchData()
///     await mock.logout()
/// }
/// ```
public func verifySequence(_ block: () async throws -> Void) async rethrows {
    // Similar to verifyOrder but checks exact sequence
    Issue.record(Comment(rawValue: "verifySequence is not yet fully implemented"))
}

// CallRecorder.shared(for:) is defined in CallRecorder.swift
