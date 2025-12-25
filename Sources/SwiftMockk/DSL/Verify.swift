import Testing
import Foundation

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
public func verify(
    times: VerificationMode = .atLeastOnce,
    _ block: () async throws -> Any?
) async rethrows {
    // Execute the closure in verifying mode and capture the pattern within the same scope
    let pattern = try await RecordingContext.shared.withMode(.verifying) {
        do {
            _ = try await block()
        } catch MockError.noStub {
            // Expected - we're in verifying mode, no stub exists or can't create dummy value
            // This is fine, we just need the call to be recorded
        } catch {
            // Re-throw other errors
            throw error
        }

        // Get the captured call pattern before exiting the task-local scope
        guard let capturedCall = RecordingContext.shared.getLastCapturedCall() else {
            Issue.record(Comment(rawValue: "No call was captured during verification"))
            return nil as MethodCall?
        }

        return capturedCall
    }

    guard let pattern = pattern else {
        return
    }

    // Find matching calls from the recorder
    // Note: We need to get the recorder from somewhere - for now use a global approach
    // In practice, the pattern.mockId tells us which mock to check
    let actualCalls = CallRecorder.shared(for: pattern.mockId).findMatching(pattern)

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
    final class CallCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var _calls: [MethodCall] = []

        func append(_ call: MethodCall) {
            lock.lock()
            defer { lock.unlock() }
            _calls.append(call)
        }

        var calls: [MethodCall] {
            lock.lock()
            defer { lock.unlock() }
            return _calls
        }
    }

    let collector = CallCollector()

    try await RecordingContext.shared.withOnCapture({ call in
        collector.append(call)
    }) {
        try await RecordingContext.shared.withMode(.verifying) {
            try await block()
        }
    }

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
