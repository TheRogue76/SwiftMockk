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
        _ = try await mock.fetchUser(id: any())
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
        _ = try await mock.fetchUser(id: "1")
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

// MARK: - Result Type Tests

public enum NetworkError: Error, Equatable {
    case timeout
    case serverError
}

@Mockable
public protocol NetworkService {
    func fetch(url: String) -> Result<Data, NetworkError>
    func upload(data: Data) async -> Result<Void, NetworkError>
}

@Test func testResultTypeSuccess() async throws {
    let mock = MockNetworkService()
    let testData = Data([1, 2, 3, 4])

    await every { mock.fetch(url: any()) }.returnsSuccess(testData, failureType: NetworkError.self)

    let result = mock.fetch(url: "https://example.com")
    guard case .success(let data) = result else {
        Issue.record("Expected success")
        return
    }
    #expect(data == testData)
}

@Test func testResultTypeFailure() async throws {
    let mock = MockNetworkService()

    await every { mock.fetch(url: any()) }.returnsFailure(NetworkError.timeout, successType: Data.self)

    let result = mock.fetch(url: "https://example.com")
    guard case .failure(let error) = result else {
        Issue.record("Expected failure")
        return
    }
    #expect(error == .timeout)
}

@Test func testResultWithExplicitConstruction() async throws {
    let mock = MockNetworkService()
    let testData = Data([1, 2, 3, 4])

    // Existing syntax should still work
    let success: Result<Data, NetworkError> = .success(testData)
    await every { mock.fetch(url: "test") }.returns(success)

    let result = mock.fetch(url: "test")
    guard case .success(let data) = result else {
        Issue.record("Expected success")
        return
    }
    #expect(data == testData)
}

@Test func testResultAsyncMethod() async throws {
    let mock = MockNetworkService()
    let testData = Data([5, 6, 7, 8])

    await every { await mock.upload(data: any()) }.returnsSuccess((), failureType: NetworkError.self)

    let result = await mock.upload(data: testData)
    guard case .success = result else {
        Issue.record("Expected success")
        return
    }
}

// MARK: - Typed Throws Tests

public enum UserError: Error, Equatable {
    case notFound
    case invalidId
    case permissionDenied
}

@Mockable
public protocol TypedThrowsService {
    func getUser(id: String) throws(UserError) -> User
    func fetchUsers() async throws(UserError) -> [User]
    func updateUser(_ user: User) throws(UserError)
}

@Test func testTypedThrowsError() async throws {
    let mock = MockTypedThrowsService()

    try await every { try mock.getUser(id: any()) }.throws(UserError.notFound)

    do {
        _ = try mock.getUser(id: "123")
        Issue.record("Expected UserError.notFound")
    } catch {
        #expect(error == .notFound)
    }
}

@Test func testTypedThrowsSuccess() async throws {
    let mock = MockTypedThrowsService()
    let testUser = User(id: "123", name: "Alice")

    try await every { try mock.getUser(id: "123") }.returns(testUser)

    let user = try mock.getUser(id: "123")
    #expect(user.id == testUser.id)
    #expect(user.name == testUser.name)
}

@Test func testAsyncTypedThrows() async throws {
    let mock = MockTypedThrowsService()

    try await every { try await mock.fetchUsers() }.throws(UserError.permissionDenied)

    do {
        _ = try await mock.fetchUsers()
        Issue.record("Expected UserError.permissionDenied")
    } catch {
        // Success
    }
}

@Test func testTypedThrowsVoidMethod() async throws {
    let mock = MockTypedThrowsService()
    let user = User(id: "123", name: "Alice")

    try await every { try mock.updateUser(user) }.throws(UserError.permissionDenied)

    do {
        try mock.updateUser(user)
        Issue.record("Expected UserError.permissionDenied")
    } catch {
        #expect(error == .permissionDenied)
    }
}

@Test func testTypedThrowsAsyncSuccess() async throws {
    let mock = MockTypedThrowsService()
    let testUsers = [User(id: "1", name: "Alice"), User(id: "2", name: "Bob")]

    try await every { try await mock.fetchUsers() }.returns(testUsers)

    let users = try await mock.fetchUsers()
    #expect(users.count == 2)
    #expect(users[0].name == "Alice")
    #expect(users[1].name == "Bob")
}

// MARK: - Generic Method Tests

@Mockable
protocol GenericRepository {
    func fetch<T: Decodable>() async throws -> T
    func save<T: Encodable>(_ item: T) async throws
}

@Test func testGenericMethodStubbing() async throws {
    struct TestUser: Codable, Equatable {
        let id: String
        let name: String
    }

    let mock = MockGenericRepository()
    let testUser = TestUser(id: "123", name: "Alice")

    // Stub generic method with type inference
    try await every { try await mock.fetch() as TestUser }.returns(testUser)

    // Call with specific type
    let result: TestUser = try await mock.fetch()

    #expect(result == testUser)
}

@Test func testGenericMethodVerification() async throws {
    struct Product: Codable, Equatable {
        let name: String
    }

    let mock = MockGenericRepository()
    let product = Product(name: "Widget")

    // Stub the method
    try await every { try await mock.save(product) }.returns(())

    // Call it
    try await mock.save(product)

    // Verify it was called (use matcher for generic parameters)
    try await verify { try await mock.save(any() as Product) }
}

@Test func testGenericMethodWithMatchers() async throws {
    struct Item: Codable, Equatable {
        let value: Int
    }

    let mock = MockGenericRepository()

    // Stub with matcher
    try await every { try await mock.save(any() as Item) }.returns(())

    // Call with different item
    try await mock.save(Item(value: 99))

    // Verify with matcher
    try await verify { try await mock.save(any() as Item) }
}

// MARK: - Generic Protocol Tests

@Mockable
protocol GenericUserRepository {
    associatedtype User
    func fetch(id: String) async throws -> User
    func save(_ user: User) async throws
}

// Note: Primary associated type syntax <User> tested in macro expansion tests
// Runtime tests use traditional associatedtype syntax for compatibility

@Test func testGenericProtocolStubbing() async throws {
    struct TestUser: Equatable {
        let id: String
        let name: String
    }

    let mock = MockGenericUserRepository<TestUser>()
    let testUser = TestUser(id: "123", name: "Bob")

    try await every { try await mock.fetch(id: "123") }.returns(testUser)

    let result = try await mock.fetch(id: "123")
    #expect(result == testUser)
}

@Test func testGenericProtocolWithDifferentTypes() async throws {
    struct Product: Equatable {
        let name: String
    }

    let productRepo = MockGenericUserRepository<Product>()
    let testProduct = Product(name: "Widget")

    try await every { try await productRepo.fetch(id: "p1") }.returns(testProduct)

    let result = try await productRepo.fetch(id: "p1")
    #expect(result.name == "Widget")
}

// MARK: - Associated Type Tests

@Mockable
protocol AssociatedTypeContainer {
    associatedtype Item
    func add(_ item: Item)
    func getAll() -> [Item]
}

@Test func testAssociatedTypeStubbing() async throws {
    let mock = MockAssociatedTypeContainer<String>()

    await every { mock.getAll() }.returns(["Hello", "World"])

    let result = mock.getAll()
    #expect(result == ["Hello", "World"])
}

@Mockable
protocol AssociatedTypeMapper {
    associatedtype Input
    associatedtype Output
    func map(_ input: Input) -> Output
}

@Test func testAssociatedTypeMultiple() async throws {
    let mock = MockAssociatedTypeMapper<Int, String>()

    await every { mock.map(42) }.returns("42")

    let result = mock.map(42)
    #expect(result == "42")
}
