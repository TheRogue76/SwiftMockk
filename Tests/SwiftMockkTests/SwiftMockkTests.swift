import Testing
import Foundation
@testable import SwiftMockk

// MARK: - Test Protocols

@Mockable
protocol UserService {
    func fetchUser(id: String) async throws -> User
    func deleteUser(id: String) async throws
    func updateUser(_ user: User) async throws -> User
}

@Mockable
protocol SimpleCalculator {
    func add(a: Int, b: Int) -> Int
    func divide(a: Int, b: Int) throws -> Int
}

// MARK: - Test Types

public struct User: Equatable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

enum CalculatorError: Error {
    case divisionByZero
}

// MARK: - Integration Tests

@Test func testBasicStubbing() async throws {
    let mock = MockUserService()

    let expectedUser = User(id: "123", name: "Alice")

    // Stub the method
    try await every { try await mock.fetchUser(id: "123") }.returns(expectedUser)

    // Call the mock
    let user = try await mock.fetchUser(id: "123")

    // Verify the result
    #expect(user == expectedUser)
    #expect(user.name == "Alice")
}

@Test func testBasicVerification() async throws {
    let mock = MockUserService()

    // Stub
    try await every { try await mock.fetchUser(id: "123") }.returns(User(id: "123", name: "Alice"))

    // Call the method
    _ = try await mock.fetchUser(id: "123")

    // Verify it was called
    try await verify { try await mock.fetchUser(id: "123") }
}

@Test func testAnyMatcher() async throws {
    let mock = MockUserService()

    let defaultUser = User(id: "0", name: "Default")

    // Stub with any() matcher
    try await every { try await mock.fetchUser(id: any()) }.returns(defaultUser)

    // Call with different IDs
    let user1 = try await mock.fetchUser(id: "123")
    let user2 = try await mock.fetchUser(id: "456")
    let user3 = try await mock.fetchUser(id: "abc")

    // All should return the default user
    #expect(user1 == defaultUser)
    #expect(user2 == defaultUser)
    #expect(user3 == defaultUser)
}

@Test func testVerificationWithAnyMatcher() async throws {
    let mock = MockUserService()

    // Stub
    try await every { try await mock.fetchUser(id: any()) }.returns(User(id: "0", name: "Default"))

    // Call multiple times
    _ = try await mock.fetchUser(id: "123")
    _ = try await mock.fetchUser(id: "456")
    _ = try await mock.fetchUser(id: "789")

    // Verify with any matcher
    try await verify(times: .exactly(3)) { try await mock.fetchUser(id: any()) }
}

@Test func testVerificationAtLeast() async throws {
    let mock = MockUserService()

    try await every { try await mock.fetchUser(id: any()) }.returns(User(id: "0", name: "Default"))

    // Call twice
    _ = try await mock.fetchUser(id: "123")
    _ = try await mock.fetchUser(id: "456")

    // Verify at least once
    try await verify(times: .atLeast(1)) { try await mock.fetchUser(id: any()) }

    // Verify at least twice
    try await verify(times: .atLeast(2)) { try await mock.fetchUser(id: any()) }
}

@Test func testVerificationExactly() async throws {
    let mock = MockUserService()

    try await every { try await mock.fetchUser(id: any()) }.returns(User(id: "0", name: "Default"))

    // Call exactly twice
    _ = try await mock.fetchUser(id: "123")
    _ = try await mock.fetchUser(id: "456")

    // Verify exactly 2
    try await verify(times: .exactly(2)) { try await mock.fetchUser(id: any()) }
}

@Test func testThrowingMethod() async throws {
    let mock = MockUserService()

    // Stub to throw an error
    try await every { try await mock.deleteUser(id: any()) }.throws(CalculatorError.divisionByZero)

    // Verify it throws
    do {
        try await mock.deleteUser(id: "123")
        Issue.record("Expected method to throw")
    } catch {
        // Expected
        #expect(error is CalculatorError)
    }
}

@Test func testMultipleMocks() async throws {
    let mock1 = MockUserService()
    let mock2 = MockUserService()

    let user1 = User(id: "1", name: "Alice")
    let user2 = User(id: "2", name: "Bob")

    // Stub both mocks differently
    try await every { try await mock1.fetchUser(id: "1") }.returns(user1)

    try await every { try await mock2.fetchUser(id: "2") }.returns(user2)

    // Call both
    let result1 = try await mock1.fetchUser(id: "1")
    let result2 = try await mock2.fetchUser(id: "2")

    // Verify they return different values
    #expect(result1.name == "Alice")
    #expect(result2.name == "Bob")
}

@Test func testCustomMatcher() async throws {
    let mock = MockUserService()

    let longIdUser = User(id: "long", name: "Long ID User")

    // Stub with custom matcher - only match IDs longer than 5 characters
    try await every {
        try await mock.fetchUser(id: match { $0.count > 5 })
    }.returns(longIdUser)

    // Call with long ID
    let result = try await mock.fetchUser(id: "verylongid")

    #expect(result == longIdUser)
}

@Test func testSimpleCalculator() async throws {
    let mock = MockSimpleCalculator()

    // Stub add method
    await every { mock.add(a: 2, b: 3) }.returns(5)

    // Test
    let result = mock.add(a: 2, b: 3)
    #expect(result == 5)

    // Verify
    await verify { mock.add(a: 2, b: 3) }
}

@Test func testCalculatorWithMatchers() async throws {
    let mock = MockSimpleCalculator()

    // Stub with any() matchers
    await every { mock.add(a: any(), b: any()) }.returns(100)

    // All calls return 100
    #expect(mock.add(a: 1, b: 2) == 100)
    #expect(mock.add(a: 5, b: 10) == 100)
    #expect(mock.add(a: 99, b: 1) == 100)
}

@Test func testDivisionByZero() async throws {
    let mock = MockSimpleCalculator()

    // Stub divide to throw when b is 0
    try await every { try mock.divide(a: any(), b: 0) }.throws(CalculatorError.divisionByZero)

    // Stub divide to return result when b is not 0
    try await every { try mock.divide(a: 10, b: 2) }.returns(5)

    // Test success case
    let result = try mock.divide(a: 10, b: 2)
    #expect(result == 5)

    // Test error case
    do {
        _ = try mock.divide(a: 10, b: 0)
        Issue.record("Expected division by zero error")
    } catch CalculatorError.divisionByZero {
        // Expected
    } catch {
        Issue.record("Wrong error type: \(error)")
    }
}

@Test func testVerificationWithDifferentArguments() async throws {
    let mock = MockUserService()

    try await every { try await mock.fetchUser(id: any()) }.returns(User(id: "0", name: "Default"))

    // Call with different arguments
    _ = try await mock.fetchUser(id: "123")
    _ = try await mock.fetchUser(id: "456")
    _ = try await mock.fetchUser(id: "123") // Duplicate

    // Verify specific call
    try await verify { try await mock.fetchUser(id: "123") }

    // Verify with any matcher for total count
    try await verify(times: .exactly(3)) { try await mock.fetchUser(id: any()) }
}

@Test func testUpdateUserWithThrows() async throws {
    let mock = MockUserService()

    let inputUser = User(id: "1", name: "Alice")
    let updatedUser = User(id: "1", name: "Alice Updated")

    // Stub update
    try await every { try await mock.updateUser(any()) }.returns(updatedUser)

    // Call
    let result = try await mock.updateUser(inputUser)

    // Verify
    #expect(result.name == "Alice Updated")
    try await verify { try await mock.updateUser(any()) }
}

// MARK: - Property Tests

@Mockable
protocol ServiceWithProperties {
    var name: String { get set }
    var count: Int { get }
}

@Test func testPropertyStubbing() async throws {
    let mock = MockServiceWithProperties()

    // Stub property getter
    await every { mock.name }.returns("TestName")

    // Get property
    let name = mock.name

    // Verify
    #expect(name == "TestName")
    await verify { mock.name }
}

@Test func testPropertySetter() async throws {
    let mock = MockServiceWithProperties()

    // Set property
    mock.name = "NewName"

    // Verify setter was called
    await verify { mock.name = "NewName" }
}

@Test func testReadOnlyProperty() async throws {
    let mock = MockServiceWithProperties()

    // Stub read-only property
    await every { mock.count }.returns(42)

    // Get property
    let count = mock.count

    // Verify
    #expect(count == 42)
}

// MARK: - Order Verification Tests

@Test func testVerifyOrder() async throws {
    let mock = MockUserService()

    // Stub
    try await every { try await mock.fetchUser(id: any()) }.returns(User(id: "0", name: "Default"))
    try await every { try await mock.deleteUser(id: any()) }.returns(())

    // Call in order: fetch, delete, fetch
    _ = try await mock.fetchUser(id: "1")
    try await mock.deleteUser(id: "1")
    _ = try await mock.fetchUser(id: "2")

    // Verify order (non-consecutive)
    try await verifyOrder {
        let _ = try await mock.fetchUser(id: any())
        try await mock.deleteUser(id: any())
    }
}

@Test func testVerifySequence() async throws {
    let mock = MockUserService()

    // Stub
    try await every { try await mock.fetchUser(id: any()) }.returns(User(id: "0", name: "Default"))
    try await every { try await mock.deleteUser(id: any()) }.returns(())

    // Call in sequence: fetch, delete
    _ = try await mock.fetchUser(id: "1")
    try await mock.deleteUser(id: "1")

    // Verify exact consecutive sequence
    try await verifySequence {
        let _ = try await mock.fetchUser(id: "1")
        try await mock.deleteUser(id: "1")
    }
}

// MARK: - Relaxed Mock Tests

@Mockable
protocol CalculatorService {
    func add(a: Int, b: Int) -> Int
    func getName() -> String
    func isReady() -> Bool
}

@Test func testRelaxedMockReturnsDefaults() async throws {
    let mock = MockCalculatorService(mode: .relaxed)

    // Call without stubbing - should return default values for primitives
    let result = mock.add(a: 5, b: 10)
    let name = mock.getName()
    let ready = mock.isReady()

    // Should return default values
    #expect(result == 0)  // Default Int
    #expect(name == "")   // Default String
    #expect(ready == false)  // Default Bool
}

@Test func testRelaxedMockWithStubbing() async throws {
    let mock = MockCalculatorService(mode: .relaxed)

    await every { mock.add(a: 1, b: 2) }.returns(100)

    // Stubbed call returns stubbed value
    let stubbed = mock.add(a: 1, b: 2)
    #expect(stubbed == 100)

    // Unstubbed call returns default value
    let unstubbed = mock.add(a: 5, b: 10)
    #expect(unstubbed == 0)
}
