# SwiftMockk

A Swift mocking library inspired by Kotlin's [mockk](https://mockk.io/), providing elegant mocking capabilities for protocol-based testing.

## Features

- ✅ **Macro-based mock generation** - Automatic mock class generation from protocols using Swift macros
- ✅ **Intuitive DSL** - `every { }` and `verify { }` syntax inspired by mockk
- ✅ **Argument matching** - Flexible matchers including `any()`, `eq()`, and custom predicates
- ✅ **Async/await support** - Full support for Swift's async/await patterns
- ✅ **Type-safe** - Compile-time type checking for all mock interactions
- ✅ **Verification modes** - `exactly`, `atLeast`, `atMost` call count verification

## Requirements

- Swift 6.2+
- macOS 10.15+ / iOS 13+

## Installation

Add SwiftMockk to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftMockk", from: "1.0.0")
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

@Test func testFetchUser() async throws {
    // Create a mock
    let mockService = MockUserService()

    // Stub the method
    await every { await mockService.fetchUser(id: "123") }
        await .returns(User(id: "123", name: "Alice"))

    // Use the mock
    let user = try await mockService.fetchUser(id: "123")

    // Verify
    #expect(user.name == "Alice")
}
```

### 3. Verify Method Calls

```swift
@Test func testUserDeletion() async throws {
    let mockService = MockUserService()

    // Setup stub
    await every { await mockService.deleteUser(id: any()) }
        await .throws(ServiceError.notFound)

    // Execute code that uses the mock
    try? await mockService.deleteUser(id: "123")

    // Verify it was called
    await verify { await mockService.deleteUser(id: "123") }
}
```

### 4. Argument Matching

SwiftMockk provides flexible argument matching:

#### Any Matcher
```swift
// Matches any value
await every { await mockService.fetchUser(id: any()) }
    await .returns(User())
```

#### Equality Matcher
```swift
// Matches specific value
await every { await mockService.fetchUser(id: eq("123")) }
    await .returns(User(id: "123"))
```

#### Custom Matchers
```swift
// Matches using a custom predicate
await every {
    await mockService.fetchUsers(minAge: match { $0 >= 18 })
} await .returns([])
```

### 5. Verification Modes

```swift
// Verify exact call count
await verify(times: .exactly(2)) {
    await mockService.fetchUser(id: any())
}

// Verify at least N calls
await verify(times: .atLeast(1)) {
    await mockService.deleteUser(id: any())
}

// Verify at most N calls
await verify(times: .atMost(3)) {
    await mockService.updateUser(any())
}
```

### 6. Stubbing Behaviors

#### Return Values
```swift
await every { await mockService.fetchUser(id: "123") }
    await .returns(User(id: "123", name: "Alice"))
```

#### Throwing Errors
```swift
await every { await mockService.fetchUser(id: "invalid") }
    await .throws(ServiceError.notFound)
```

#### Custom Behavior with Answers
```swift
await every { await mockService.updateUser(any()) } await .answers { args in
    let user = args[0] as! User
    return User(id: user.id, name: user.name.uppercased())
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

## Current Limitations

- Order verification (`verifyOrder`, `verifySequence`) not yet implemented
- Spies and relaxed mocks not yet implemented
- Property mocking not yet implemented
- Only works with protocols (cannot mock concrete classes)

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

Inspired by [mockk](https://mockk.io/) - the excellent mocking library for Kotlin.
