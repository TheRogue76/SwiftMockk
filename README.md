# SwiftMockk

[![CI](https://github.com/TheRogue76/SwiftMockk/actions/workflows/ci.yml/badge.svg)](https://github.com/TheRogue76/SwiftMockk/actions/workflows/ci.yml)
[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20iOS-lightgrey.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Swift mocking library inspired by Kotlin's [mockk](https://mockk.io/), providing elegant mocking capabilities for protocol-based testing.

## Features

- ✅ **Macro-based mock generation** - Automatic mock class generation from protocols using Swift macros
- ✅ **Intuitive DSL** - `every { }` and `verify { }` syntax inspired by mockk
- ✅ **Argument matching** - Flexible matchers including `any()`, `eq()`, and custom predicates
- ✅ **Async/await support** - Full support for Swift's async/await patterns
- ✅ **Type-safe** - Compile-time type checking for all mock interactions
- ✅ **Verification modes** - `exactly`, `atLeast`, `atMost` call count verification
- ✅ **Property mocking** - Full support for both get and get/set properties
- ✅ **Order verification** - Verify calls happened in a specific order with `verifyOrder()` and `verifySequence()`
- ✅ **Relaxed mocks** - Optional mode that returns default values for unstubbed methods

## Requirements

- Swift 6.2+
- macOS 10.15+ / iOS 13+

## Installation

Add SwiftMockk to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/TheRogue76/SwiftMockk", from: "0.2.1")
],
targets: [
    .testTarget(
        name: "YourTests",
        dependencies: ["SwiftMockk"]
    )
]
```

## Usage

### 1. Define Your Protocol

```swift
@Mockable
protocol UserService {
    func fetchUser(id: String) async throws -> User
    func deleteUser(id: String) async throws
    func updateUser(_ user: User) async throws -> User
}
```

The `@Mockable` macro automatically generates a `MockUserService` class.

### 2. Stub Method Calls

```swift
import Testing
@testable import YourModule
import SwiftMockk

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
```

### 3. Verify Method Calls

```swift
@Test func testBasicVerification() async throws {
    let mock = MockUserService()

    // Stub
    try await every { try await mock.fetchUser(id: "123") }.returns(User(id: "123", name: "Alice"))

    // Call the method
    _ = try await mock.fetchUser(id: "123")

    // Verify it was called
    try await verify { try await mock.fetchUser(id: "123") }
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
    try await every { try await mock.fetchUser(id: any()) }.returns(defaultUser)

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
    try await every {
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

    try await every { try await mock.fetchUser(id: any()) }.returns(User(id: "0", name: "Default"))

    // Call exactly twice
    _ = try await mock.fetchUser(id: "123")
    _ = try await mock.fetchUser(id: "456")

    // Verify exactly 2
    try await verify(times: .exactly(2)) { try await mock.fetchUser(id: any()) }
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
```

### 6. Stubbing Behaviors

#### Return Values
```swift
@Test func testBasicStubbing() async throws {
    let mock = MockUserService()
    let expectedUser = User(id: "123", name: "Alice")

    // Stub the method
    try await every { try await mock.fetchUser(id: "123") }.returns(expectedUser)

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
```

## API Comparison with Kotlin mockk

| Feature | Kotlin mockk | SwiftMockk |
|---------|-------------|------------|
| Mock creation | `mockk<Service>()` | `@Mockable` + `MockService()` |
| Stubbing | `every { mock.method() } returns value` | `await every { await mock.method() } await .returns(value)` |
| Verification | `verify { mock.method() }` | `await verify { await mock.method() }` |
| Async stubbing | `coEvery { mock.method() } returns value` | Same as stubbing (unified API) |
| Matchers | `any()`, `eq()`, `match {}` | `any()`, `eq()`, `match {}` |
| Call count | `verify(exactly = 2) { }` | `verify(times: .exactly(2)) { }` |

## Differences from Kotlin mockk

Due to Swift's language design and concurrency model, SwiftMockk has some differences:

1. **Async by default**: All DSL functions (`every`, `verify`) are async in SwiftMockk because Swift's actor-based concurrency requires async access
2. **Macro-based**: Swift uses compile-time macros instead of runtime bytecode manipulation
3. **Protocol-only**: Can only mock protocols, not classes (Swift limitation)
4. **Explicit await**: Swift requires explicit `await` keywords for async operations

### 7. Property Mocking

```swift
@Mockable
protocol ServiceWithProperties {
    var name: String { get set }
    var count: Int { get }
}

@Test func testPropertyStubbing() async throws {
    let mock = MockServiceWithProperties()

    // Stub property getter
    try await every { mock.name }.returns("TestName")

    // Get property
    let name = mock.name

    // Verify
    #expect(name == "TestName")
    try await verify { mock.name }
}

@Test func testPropertySetter() async throws {
    let mock = MockServiceWithProperties()

    // Set property
    mock.name = "NewName"

    // Verify setter was called
    try await verify { mock.name = "NewName" }
}

@Test func testReadOnlyProperty() async throws {
    let mock = MockServiceWithProperties()

    // Stub read-only property
    try await every { mock.count }.returns(42)

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
    try await every { try await mock.fetchUser(id: any()) }.returns(User(id: "0", name: "Default"))
    try await every { try await mock.deleteUser(id: any()) }.returns(())

    // Call in order: fetch, delete, fetch
    _ = try await mock.fetchUser(id: "1")
    try await mock.deleteUser(id: "1")
    _ = try await mock.fetchUser(id: "2")

    // Verify order (non-consecutive)
    try await verifyOrder {
        try await mock.fetchUser(id: any())
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
        try await mock.fetchUser(id: "1")
        try await mock.deleteUser(id: "1")
    }
}
```

### 9. Relaxed Mocks

```swift
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

    try await every { mock.add(a: 1, b: 2) }.returns(100)

    // Stubbed call returns stubbed value
    let stubbed = mock.add(a: 1, b: 2)
    #expect(stubbed == 100)

    // Unstubbed call returns default value
    let unstubbed = mock.add(a: 5, b: 10)
    #expect(unstubbed == 0)
}
```

## Current Limitations

- Relaxed mocks only work with primitive types (Int, String, Bool, etc.), not complex structs
- Spies not yet implemented (cannot call through to real implementations)
- Only works with protocols (cannot mock concrete classes)

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

Inspired by [mockk](https://mockk.io/) - the excellent mocking library for Kotlin and [Mockable](https://github.com/Kolos65/Mockable/tree/main) for the Swift Macro idea.