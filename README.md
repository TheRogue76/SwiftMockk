# SwiftMockk

[![CI](https://github.com/TheRogue76/SwiftMockk/actions/workflows/ci.yml/badge.svg)](https://github.com/TheRogue76/SwiftMockk/actions/workflows/ci.yml)
[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20iOS-lightgrey.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Swift mocking library inspired by Kotlin's [mockk](https://mockk.io/), providing elegant mocking capabilities for protocol-based testing.

## Features

- **Test-target only dependency** - No need to add SwiftMockk to your main target
- **Build-phase mock generation** - Automatic mock class generation using SPM build tool plugin
- **Intuitive DSL** - `every { }` and `verify { }` syntax inspired by mockk
- **Argument matching** - Flexible matchers including `any()`, `eq()`, and custom predicates
- **Async/await support** - Full support for Swift's async/await patterns
- **Type-safe** - Compile-time type checking for all mock interactions
- **Verification modes** - `exactly`, `atLeast`, `atMost` call count verification
- **Property mocking** - Full support for both get and get/set properties
- **Order verification** - Verify calls happened in a specific order with `verifyOrder()` and `verifySequence()`
- **Relaxed mocks** - Optional mode that returns default values for unstubbed methods
- **Result type support** - Convenience methods for stubbing `Result<Success, Failure>` return types
- **Typed throws support** - Full support for Swift 6's typed throws syntax `throws(ErrorType)`
- **Generics support** - Full support for generic methods, generic protocols, and associated types
- **Kotlin-style mockk() function** - Create mocks using `mockk(Protocol.self)` syntax

## Requirements

- Swift 6.0+
- macOS 12+ / iOS 13+

## Installation

Add SwiftMockk to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/TheRogue76/SwiftMockk", from: "<version>")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: []  // No SwiftMockk dependency needed in main target!
    ),
    .testTarget(
        name: "YourAppTests",
        dependencies: ["YourApp", "SwiftMockk"],
        plugins: [.plugin(name: "SwiftMockkGeneratorPlugin", package: "SwiftMockk")]
    )
]
```

## Usage

### 1. Mark Your Protocol

In your main target, mark protocols with the `// swiftmockk:generate` comment. **No imports needed!**

```swift
// UserService.swift (in your main target)

// swiftmockk:generate
protocol UserService {
    func fetchUser(id: String) async throws -> User
    func deleteUser(id: String) async throws
    func updateUser(_ user: User) async throws -> User
}
```

The build tool plugin automatically scans for marked protocols and generates a `MockUserService` class during compilation.

### 2. Create Mocks

You can create mocks in two ways:

#### Option A: Kotlin-style `mockk()` function (Recommended)

```swift
import Testing
@testable import YourModule
import SwiftMockk

@Test func testWithMockk() async throws {
    // Create mock using mockk() - similar to Kotlin
    let mock = mockk(UserService.self)

    // Create relaxed mock
    let relaxedMock = mockk(UserService.self, mode: .relaxed)

    // Use as normal
    await every { try await mock.fetchUser(id: "123") }.returns(expectedUser)
}
```

**Note**: The first time you instantiate any mock (using `mockk()` or direct instantiation), all mocks in that file are automatically registered with the registry.

#### Option B: Direct instantiation

```swift
let mock = MockUserService()
let relaxedMock = MockUserService(mode: .relaxed)
```

Both approaches work identically. The `mockk()` function provides a more Kotlin-like API.

**Error Handling**: If you need to handle registration errors, use `tryMockk()`:

```swift
do {
    let mock = try tryMockk(UserService.self)
} catch MockRegistryError.notRegistered(let name) {
    // Handle missing mock registration
}
```

**Limitation**: Generic protocols (those with associated types) cannot use `mockk()`. Use direct instantiation instead:
```swift
// For generic protocols, use direct instantiation:
let repo = MockRepository<User>()  // Works
// mockk(Repository<User>.self)    // Won't work
```

#### Important: Using mockk() with Stored Property Initializers

Due to Swift's lazy evaluation of file-level constants, `mockk()` requires special handling when used as a stored property initializer (before any mock has been instantiated):

```swift
// ❌ This will crash - mockk() called before any mock is instantiated
final class MyTests: XCTestCase {
    let mock: UserService = mockk(UserService.self)  // Crashes!
}
```

**Solutions:**

**Option 1: Call `_swiftMockkBootstrap()` in class setUp (Recommended for XCTest)**
```swift
final class MyTests: XCTestCase {
    var mock: UserService!  // Change to var

    override class func setUp() {
        super.setUp()
        _swiftMockkBootstrap()  // Triggers mock registration
    }

    override func setUp() {
        super.setUp()
        mock = mockk(UserService.self)  // Now works!
    }
}
```

**Option 2: Use direct instantiation**
```swift
final class MyTests: XCTestCase {
    let mock: UserService = MockUserService()  // Always works
}
```

**Option 3: Use lazy var**
```swift
final class MyTests: XCTestCase {
    lazy var mock: UserService = mockk(UserService.self)

    override func setUp() {
        super.setUp()
        _ = mock  // Accessing lazy var triggers registration
    }
}
```

**Why this happens**: Swift evaluates file-level constants lazily. The mock registration code only runs when a mock is first instantiated. When `mockk()` is called as a stored property initializer, no mock has been instantiated yet, so the registry is empty.

**When mockk() works without workarounds**:
- When called inside test methods (after setUp has run)
- When called after any mock has been directly instantiated
- In Swift Testing `@Test` functions (they run after module initialization)

### 3. Stub Method Calls

```swift
import Testing
@testable import YourModule
import SwiftMockk

@Test func testBasicStubbing() async throws {
    let mock = mockk(UserService.self)

    let expectedUser = User(id: "123", name: "Alice")

    // Stub the method
    await every { try await mock.fetchUser(id: "123") }.returns(expectedUser)

    // Call the mock
    let user = try await mock.fetchUser(id: "123")

    // Verify the result
    #expect(user == expectedUser)
    #expect(user.name == "Alice")
}
```

### 3. Verify Method Calls

```swift
@Test func testBasicVerification() async throws {
    let mock = MockUserService()

    // Stub
    await every { try await mock.fetchUser(id: "123") }.returns(User(id: "123", name: "Alice"))

    // Call the method
    _ = try await mock.fetchUser(id: "123")

    // Verify it was called
    await verify { try await mock.fetchUser(id: "123") }
}
```

### 4. Argument Matching

SwiftMockk provides flexible argument matching:

#### Any Matcher
```swift
@Test func testAnyMatcher() async throws {
    let mock = MockUserService()
    let defaultUser = User(id: "0", name: "Default")

    // Stub with any() matcher
    await every { try await mock.fetchUser(id: any()) }.returns(defaultUser)

    // Call with different IDs
    let user1 = try await mock.fetchUser(id: "123")
    let user2 = try await mock.fetchUser(id: "456")

    // All return the default user
    #expect(user1 == defaultUser)
    #expect(user2 == defaultUser)
}
```

#### Custom Matchers
```swift
@Test func testCustomMatcher() async throws {
    let mock = MockUserService()
    let longIdUser = User(id: "long", name: "Long ID User")

    // Stub with custom matcher - only match IDs longer than 5 characters
    await every {
        try await mock.fetchUser(id: match { $0.count > 5 })
    }.returns(longIdUser)

    // Call with long ID
    let result = try await mock.fetchUser(id: "verylongid")
    #expect(result == longIdUser)
}
```

### 5. Verification Modes

```swift
@Test func testVerificationExactly() async throws {
    let mock = MockUserService()

    await every { try await mock.fetchUser(id: any()) }.returns(User(id: "0", name: "Default"))

    // Call exactly twice
    _ = try await mock.fetchUser(id: "123")
    _ = try await mock.fetchUser(id: "456")

    // Verify exactly 2
    await verify(times: .exactly(2)) { try await mock.fetchUser(id: any()) }
}

@Test func testVerificationAtLeast() async throws {
    let mock = MockUserService()

    await every { try await mock.fetchUser(id: any()) }.returns(User(id: "0", name: "Default"))

    // Call twice
    _ = try await mock.fetchUser(id: "123")
    _ = try await mock.fetchUser(id: "456")

    // Verify at least once
    await verify(times: .atLeast(1)) { try await mock.fetchUser(id: any()) }

    // Verify at least twice
    await verify(times: .atLeast(2)) { try await mock.fetchUser(id: any()) }
}
```

### 6. Stubbing Behaviors

#### Return Values
```swift
@Test func testBasicStubbing() async throws {
    let mock = MockUserService()
    let expectedUser = User(id: "123", name: "Alice")

    // Stub the method
    await every { try await mock.fetchUser(id: "123") }.returns(expectedUser)

    // Call the mock
    let user = try await mock.fetchUser(id: "123")
    #expect(user == expectedUser)
}
```

#### Throwing Errors
```swift
@Test func testThrowingMethod() async throws {
    let mock = MockUserService()

    // Stub to throw an error
    await every { try await mock.deleteUser(id: any()) }.throws(ServiceError.notFound)

    // Verify it throws
    do {
        try await mock.deleteUser(id: "123")
        Issue.record("Expected method to throw")
    } catch {
        // Expected
        #expect(error is ServiceError)
    }
}
```

## API Comparison with Kotlin mockk

| Feature | Kotlin mockk | SwiftMockk |
|---------|-------------|------------|
| Mock creation | `mockk<Service>()` | `mockk(Service.self)` or `MockService()` |
| Stubbing | `every { mock.method() } returns value` | `await every { await mock.method() }.returns(value)` |
| Verification | `verify { mock.method() }` | `await verify { await mock.method() }` |
| Async stubbing | `coEvery { mock.method() } returns value` | Same as stubbing (unified API) |
| Matchers | `any()`, `eq()`, `match {}` | `any()`, `eq()`, `match {}` |
| Call count | `verify(exactly = 2) { }` | `verify(times: .exactly(2)) { }` |
| Relaxed mocks | `mockk(relaxed = true)` | `mockk(Service.self, mode: .relaxed)` |

## Differences from Kotlin mockk

Due to Swift's language design and concurrency model, SwiftMockk has some differences:

1. **Async by default**: All DSL functions (`every`, `verify`) are async in SwiftMockk because Swift's actor-based concurrency requires async access
2. **Build-phase generation**: Swift uses build-phase code generation instead of runtime bytecode manipulation
3. **Protocol-only**: Can only mock protocols, not classes (Swift limitation)
4. **Explicit await**: Swift requires explicit `await` keywords for async operations

### 7. Property Mocking

```swift
// swiftmockk:generate
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
```

### 8. Order Verification

```swift
@Test func testVerifyOrder() async throws {
    let mock = MockUserService()

    // Stub
    await every { try await mock.fetchUser(id: any()) }.returns(User(id: "0", name: "Default"))
    await every { try await mock.deleteUser(id: any()) }.returns(())

    // Call in order: fetch, delete, fetch
    _ = try await mock.fetchUser(id: "1")
    try await mock.deleteUser(id: "1")
    _ = try await mock.fetchUser(id: "2")

    // Verify order (non-consecutive)
    await verifyOrder {
        try await mock.fetchUser(id: any())
        try await mock.deleteUser(id: any())
    }
}

@Test func testVerifySequence() async throws {
    let mock = MockUserService()

    // Stub
    await every { try await mock.fetchUser(id: any()) }.returns(User(id: "0", name: "Default"))
    await every { try await mock.deleteUser(id: any()) }.returns(())

    // Call in sequence: fetch, delete
    _ = try await mock.fetchUser(id: "1")
    try await mock.deleteUser(id: "1")

    // Verify exact consecutive sequence
    await verifySequence {
        try await mock.fetchUser(id: "1")
        try await mock.deleteUser(id: "1")
    }
}
```

### 9. Relaxed Mocks

```swift
// swiftmockk:generate
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
```

### 10. Result Type Support

SwiftMockk provides convenience methods for stubbing methods that return `Result<Success, Failure>`:

```swift
public enum NetworkError: Error, Equatable {
    case timeout
    case serverError
}

// swiftmockk:generate
public protocol NetworkService {
    func fetch(url: String) -> Result<Data, NetworkError>
}

@Test func testResultTypeSuccess() async throws {
    let mock = MockNetworkService()
    let testData = Data([1, 2, 3, 4])

    // Use convenience method for success
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

    // Use convenience method for failure
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

    // Or use explicit Result construction
    let success: Result<Data, NetworkError> = .success(testData)
    await every { mock.fetch(url: "test") }.returns(success)

    let result = mock.fetch(url: "test")
    guard case .success(let data) = result else {
        Issue.record("Expected success")
        return
    }
    #expect(data == testData)
}
```

**Note**: Due to Swift's type inference limitations, both convenience methods require explicit type parameters:
- `returnsSuccess(_:failureType:)` - requires the failure error type
- `returnsFailure(_:successType:)` - requires the success value type

### 11. Typed Throws Support (Swift 6+)

SwiftMockk supports Swift 6's typed throws syntax. When a protocol method uses typed throws, the generated mock preserves the error type:

```swift
public enum UserError: Error, Equatable {
    case notFound
    case invalidId
}

// Note: Swift 6+ typed throws syntax: throws(ErrorType)
// swiftmockk:generate
public protocol UserService {
    func getUser(id: String) throws(UserError) -> User
    func fetchUsers() async throws(UserError) -> [User]
}

@Test func testTypedThrows() async throws {
    let mock = MockUserService()

    // Stub to throw a specific error type
    await every { try mock.getUser(id: any()) }.throws(UserError.notFound)

    do {
        _ = try mock.getUser(id: "123")
        Issue.record("Expected UserError.notFound")
    } catch let error as UserError {
        #expect(error == .notFound)
    }
}
```

**Important Notes on Typed Throws**:
- Typed throws syntax `throws(ErrorType)` requires Swift 6+ language mode
- **Typed throws methods MUST be stubbed**: If a typed throws method is called without a stub, it will `fatalError()` instead of throwing `MockError.noStub`. This is because Swift's typed throws cannot throw `MockError` - only the specific error type
- When stubbing typed throws methods, the error you provide must match the error type (e.g., `UserError` for `throws(UserError)`)
- User-provided errors from stubs are automatically cast to the correct type

### 12. Generics Support

SwiftMockk provides comprehensive support for generics in protocols, including generic methods, generic protocols, and associated types.

#### Generic Methods

Methods with type parameters are fully supported, including constraints and where clauses:

```swift
// swiftmockk:generate
protocol DataRepository {
    func fetch<T: Decodable>() async throws -> T
    func save<T: Encodable>(_ item: T) async throws
    func process<T>(_ data: T) throws -> String where T: Codable & Sendable
}

@Test func testGenericMethod() async throws {
    let mock = MockDataRepository()

    struct User: Codable, Equatable {
        let id: String
        let name: String
    }

    let testUser = User(id: "123", name: "Alice")

    // Stub with type inference
    await every { try await mock.fetch() as User }.returns(testUser)

    // Call with specific type
    let result: User = try await mock.fetch()

    #expect(result == testUser)
}
```

**Key Points**:
- Type inference works naturally - specify the return type when stubbing
- Generic constraints (e.g., `T: Decodable`) are preserved
- Where clauses are fully supported

#### Generic Protocols

Protocols with primary associated types (Swift 5.7+) are fully supported:

```swift
// swiftmockk:generate
protocol Repository<Entity> {
    func fetch(id: String) async throws -> Entity
    func save(_ entity: Entity) async throws
    func delete(id: String) async throws
}

@Test func testGenericProtocol() async throws {
    struct Product: Equatable {
        let id: String
        let name: String
    }

    // Instantiate with specific type
    let productRepo = MockRepository<Product>()
    let testProduct = Product(id: "p1", name: "Widget")

    await every { try await productRepo.fetch(id: "p1") }.returns(testProduct)

    let result = try await productRepo.fetch(id: "p1")
    #expect(result == testProduct)
}
```

**Key Points**:
- Works with primary associated types: `protocol Repository<Entity>`
- Create mocks with specific types: `MockRepository<Product>()`
- Can create multiple mocks with different types in the same test

#### Associated Types

Traditional `associatedtype` declarations are automatically converted to generic parameters:

```swift
// swiftmockk:generate
protocol Container {
    associatedtype Item
    func add(_ item: Item)
    func getAll() -> [Item]
}

@Test func testAssociatedTypes() async throws {
    // MockContainer<Item> is generated
    let stringContainer = MockContainer<String>()

    await every { stringContainer.getAll() }.returns(["Hello", "World"])

    let result = stringContainer.getAll()
    #expect(result == ["Hello", "World"])
}
```

**Key Points**:
- Associated types are converted to generic parameters on the mock class
- Constraints on associated types are preserved as where clauses
- Multiple associated types are supported: `associatedtype Input` + `associatedtype Output`

#### Multiple Type Parameters

Protocols with multiple type parameters work seamlessly:

```swift
// swiftmockk:generate
protocol Cache<Key, Value> where Key: Hashable {
    func get(_ key: Key) -> Value?
    func set(_ key: Key, value: Value)
}

@Test func testMultipleTypeParameters() async throws {
    let cache = MockCache<String, Int>()

    await every { cache.get("answer") }.returns(42)

    let result = cache.get("answer")
    #expect(result == 42)
}
```

#### Variadic Generics (Swift 5.9+)

Variadic generics with parameter packs are fully supported:

```swift
// swiftmockk:generate
protocol VariadicProcessor {
    func process<each T>(_ values: repeat each T) -> (repeat each T)
}

@Test func testVariadicGenerics() async throws {
    let mock = MockVariadicProcessor()

    // Stub with multiple types
    await every { mock.process("Hello", 42, true) }.returns(("Hello", 42, true))

    let result = mock.process("Hello", 42, true)
    #expect(result.0 == "Hello")
    #expect(result.1 == 42)
    #expect(result.2 == true)
}
```

**Note**: Parameter pack arguments aren't recorded individually (due to Swift type erasure limitations), but stubbing and verification by method name work correctly.

## Current Limitations

- **mockk() with stored property initializers**: Due to Swift's lazy evaluation, `mockk()` cannot be used as a stored property initializer without workarounds. See [Using mockk() with Stored Property Initializers](#important-using-mockk-with-stored-property-initializers) for solutions.
- **Generic protocols and mockk()**: Generic protocols (those with associated types or type parameters) cannot use `mockk()` - use direct instantiation instead: `MockRepository<User>()`
- **Typed throws methods must be stubbed**: Unstubbed typed throws methods will `fatalError()` instead of throwing `MockError.noStub` (see Typed Throws section above)
- **Relaxed mocks**: Relaxed mode only works with primitive types (Int, String, Bool, etc.), not complex structs or Result types
- **Spies**: Not yet implemented (cannot call through to real implementations)
- **Protocol-only**: Can only mock protocols, not concrete classes

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

Inspired by [mockk](https://mockk.io/) - the excellent mocking library for Kotlin and [Mockable](https://github.com/Kolos65/Mockable/tree/main) for the Swift Macro idea.
