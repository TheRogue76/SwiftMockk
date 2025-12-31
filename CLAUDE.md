# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftMockk is a Swift mocking library inspired by Kotlin's mockk. It uses Swift Macros to generate mock implementations from protocols, providing a fluent DSL for stubbing and verification.

## Build and Test Commands

### Building
```bash
swift build
```

### Running Tests
```bash
# Run all tests
swift test

# Run specific test
swift test --filter SwiftMockkTests.<test-name>
```

### Other Commands
```bash
# Clean build artifacts
swift package clean

# Update package dependencies
swift package update
```

## Architecture Overview

SwiftMockk uses a **two-layer architecture**:

1. **Macro Layer** (`Sources/SwiftMockkMacros/`): Generates mock classes at compile time
2. **Runtime Layer** (`Sources/SwiftMockk/`): Provides DSL, call recording, and stub management

### Why Macros Instead of Runtime Interception

Unlike Kotlin's mockk (which uses JVM bytecode manipulation), Swift uses static dispatch and cannot intercept method calls at runtime. SwiftMockk uses compile-time macros to generate explicit mock implementations that record and stub calls.

## Directory Structure

```
Sources/
├── SwiftMockk/                    # Runtime library (public API)
│   ├── SwiftMockk.swift          # Main exports, @Mockable macro declaration
│   ├── DSL/
│   │   ├── Every.swift           # every() function for stubbing
│   │   ├── Verify.swift          # verify() functions and VerificationMode
│   │   └── Stubbing.swift        # Stubbing builder class
│   ├── Matchers/
│   │   ├── ArgumentMatcher.swift # (defined in MethodCall.swift)
│   │   ├── Matchers.swift        # any(), eq(), match() functions
│   │   └── MatcherRegistry.swift # Thread-safe matcher storage
│   ├── Recording/
│   │   ├── CallRecorder.swift    # Records method invocations per mock
│   │   ├── MethodCall.swift      # Represents a method call
│   │   ├── RecordingContext.swift # Global recording mode state
│   │   └── StubbingRegistry.swift # Stores stubs globally by mock ID
│   └── Protocols/
│       └── Mockable.swift        # Base protocol for generated mocks
│
└── SwiftMockkMacros/              # Macro implementation (internal)
    ├── SwiftMockkPlugin.swift    # CompilerPlugin entry point
    └── MockableMacro.swift       # @Mockable PeerMacro implementation
```

## Key Technical Details

### Swift Concurrency and Thread Safety

- **All DSL functions are async**: `every {}` and `verify {}` are async for consistency and future extensibility
- **Synchronous locking**: All registries (`RecordingContext`, `CallRecorder`, `StubbingRegistry`, `MatcherRegistry`) use `NSLock` for thread-safe synchronous access
- **No actors**: While actors were considered, the implementation uses classes with `@unchecked Sendable` and explicit locking to avoid async context restrictions
- **Recording mode**: Global `RecordingContext.shared` manages whether we're in normal/stubbing/verifying mode

### How Mock Generation Works

1. User annotates protocol with `@Mockable`
2. `MockableMacro` (PeerMacro) parses the protocol declaration
3. Generates `Mock{ProtocolName}` class that:
   - Implements all protocol methods
   - Each method extracts matchers, creates a `MethodCall`, and records it
   - Methods look up stubs from `StubbingRegistry.shared` and return stubbed values

**Generated mock example:**
```swift
public class MockUserService: UserService, Mockable {
    public let _mockId = UUID().uuidString
    public var _recorder: CallRecorder { CallRecorder.shared(for: _mockId) }

    public func fetchUser(id: String) async throws -> User {
        let matchers = MatcherRegistry.shared.extractMatchers()
        let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
        let call = MethodCall(mockId: _mockId, name: "fetchUser", args: [id], matchMode: matchMode)
        await _recorder.record(call)
        return try await StubbingRegistry.shared.getAsyncStub(for: call)
    }
}
```

### How Stubbing Works

1. `every { await mock.method(args) }` enters stubbing mode by calling `RecordingContext.shared.enterMode(.stubbing)`
2. Executes the closure → triggers the mock method
3. Mock method checks the mode, sees it's in stubbing mode, and:
   - Records the call to `RecordingContext.shared`
   - Returns early with a dummy value (never actually used)
4. `every` retrieves the captured call from `RecordingContext.shared.getLastCapturedCall()`
5. `every` exits stubbing mode and returns a `Stubbing` builder object
6. User calls `.returns(value)` on the builder
7. Stub is registered in `StubbingRegistry.shared` keyed by `(mockId, methodName)`

### How Verification Works

1. `verify { await mock.method(args) }` enters verifying mode
2. Executes the closure → captures the call pattern
3. Retrieves actual calls from `CallRecorder.shared(for: mockId)`
4. Matches actual calls against the pattern
5. Checks if count satisfies the `VerificationMode`
6. Uses Swift Testing's `Issue.record()` to report failures

### How Matchers Work

1. `any()`, `eq()`, `match {}` are called during argument evaluation
2. They register matchers in `MatcherRegistry.shared` (thread-safe with NSLock)
3. When mock method executes, it extracts matchers and attaches them to `MethodCall`
4. During verification/stubbing lookup, matchers are used instead of exact value comparison

### Property Mocking

Properties in protocols are now fully supported. The macro generates:
- Backing storage (`_propertyName`) for each property
- Getter that records calls and looks up stubs
- Setter (for get/set properties) that records calls and updates backing storage

**Property access is recorded as method calls:**
- Getter: `get_propertyName`
- Setter: `set_propertyName`

**Example:**
```swift
@Mockable
protocol Service {
    var name: String { get set }
    var count: Int { get }
}

let mock = MockService()
await every { mock.name } await .returns("Test")
await every { mock.count } await .returns(42)
```

### Order Verification

Two new verification functions:

1. **`verifyOrder`**: Verifies calls appear in the specified order, but not necessarily consecutively
   - Example: If actual calls are [A, X, B, Y, C], verifying [A, B, C] passes

2. **`verifySequence`**: Verifies calls appear as an exact consecutive sequence
   - Example: Actual calls must contain [A, B, C] as a consecutive subsequence

**Implementation:**
- Both functions use a `CallCollector` to capture expected calls during verification mode
- `verifyOrder` uses a two-pointer algorithm to find calls in order
- `verifySequence` checks all possible starting positions for the sequence

### Relaxed Mocks

Mocks can now be created in "relaxed" mode where unstubbed methods return default values instead of throwing:

```swift
let mock = MockService(mode: .relaxed)  // Default is .strict
```

**How it works:**
- Each mock has a `_mockMode: MockMode` property
- Stub lookup helpers check the mode after failing to find a stub
- In relaxed mode, `_mockDummyValue()` is called to return a default value
- **Limitation**: Only works for primitive types (Int, String, Bool, etc.)

**Mode is passed to stub helpers:**
```swift
return try _mockGetStub(for: call, mockMode: _mockMode)
```

### Result Type Support

SwiftMockk provides convenience DSL methods for stubbing methods that return `Result<Success, Failure>`:

**DSL methods (in `Stubbing.swift`):**
- `returnsSuccess<Success, Failure: Error>(_ value: Success, failureType: Failure.Type)`
- `returnsFailure<Success, Failure: Error>(_ error: Failure, successType: Success.Type)`

**Implementation:**
- Both methods construct a `Result` value and register it using `.value()` behavior
- Type parameters must be explicit due to Swift's type inference limitations
- Result types work naturally with the existing stub system - no special handling needed

**Example:**
```swift
@Mockable
protocol NetworkService {
    func fetch(url: String) -> Result<Data, NetworkError>
}

let mock = MockNetworkService()
await every { mock.fetch(url: any()) }.returnsSuccess(data, failureType: NetworkError.self)
await every { mock.fetch(url: any()) }.returnsFailure(NetworkError.timeout, successType: Data.self)

// Or use explicit Result construction
let success: Result<Data, NetworkError> = .success(data)
await every { mock.fetch(url: any()) }.returns(success)
```

**Special handling in `_mockDummyValue()`:**
- Result types cannot be safely created as dummy values in relaxed mode
- During stubbing/verifying mode, returns uninitialized memory (safe because value is never used)
- In relaxed mode, throws `MockError.noStub` to require explicit stubbing

### Typed Throws Support

SwiftMockk supports Swift 6's typed throws syntax `throws(ErrorType)` in protocol methods.

**Macro implementation (`MockableMacro.swift`):**
- `extractThrowsInfo()` helper inspects the SwiftSyntax AST for each function's `throwsClause`
- Uses `throwsClause?.type` to detect and extract the typed throws clause
- Generated methods preserve the typed throws clause from the parsed syntax in their signature

**Example protocol:**
```swift
@Mockable
protocol UserService {
    func getUser(id: String) throws(UserError) -> User
    func updateUser(_ user: User) throws(UserError)
}
```

**Generated method:**
```swift
public func getUser(id: String) throws(UserError) -> User {
    let matchers = MatcherRegistry.shared.extractMatchers()
    let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
    let call = MethodCall(mockId: _mockId, name: "getUser", args: [id], matchMode: matchMode)
    _recorder.record(call)
    return try _mockGetStub(for: call, mockMode: _mockMode)
}
```

**Key design decisions:**
- No runtime type validation needed - Swift's type system enforces correctness at compile time
- Typed errors conform to `Error`, so existing stub system works without changes
- `.throws()` DSL method works naturally with typed throws
- Stub storage remains type-erased (`Error`), but method signatures are type-safe

**Limitations:**
- Requires Swift 6+ language mode
- Requires swift-syntax 600.0.0+ for typed throws support (older versions are not supported)

## Important Patterns and Conventions

### Sendable Compliance (Swift 6)

- Use `@unchecked Sendable` for types storing `Any` or closures: `MethodCall`, `StubBehavior`, matchers
- Use `@unchecked Sendable` for registries with manual synchronization: `RecordingContext`, `StubbingRegistry`, `CallRecorder`, `MatcherRegistry`
- All mutable shared state is protected with `NSLock` for thread-safety
- This approach avoids the async context restrictions that come with actor isolation

### Mock ID System

- Each mock gets a unique `UUID().uuidString` as `_mockId`
- Global registries (`StubbingRegistry`, `CallRecorder`) are keyed by mock ID
- This allows multiple mocks to coexist without interference

### Recording Modes

Three modes in `RecordingContext`:
- **normal**: Method calls are recorded for verification
- **stubbing**: Method calls are captured but not recorded (for `every {}`)
- **verifying**: Method calls are captured but not recorded (for `verify {}`)

### Argument Matching

`MethodCall.MatchMode`:
- **exact**: Use `areEqual()` to compare actual argument values
- **matchers([ArgumentMatcher])**: Use registered matchers for comparison

## Common Development Tasks

### Adding a New Matcher

1. Create a struct conforming to `ArgumentMatcher` (mark `@unchecked Sendable` if needed)
2. Implement `matches(_ value: Any) -> Bool`
3. Add a public function in `Matchers.swift` that registers it:
```swift
public func myMatcher<T>(/* params */) -> T {
    MatcherRegistry.shared.register(MyMatcher(/* params */))
    return unsafeBitCast(0, to: T.self) // or return actual value
}
```

### Adding a New Verification Mode

1. Add case to `VerificationMode` enum in `Verify.swift`
2. Implement `matches(_ count: Int) -> Bool` for the new case
3. Add `description` for error messages

### Extending Generated Mock Methods

Modify `MockableMacro.generateMockMethod()` in `MockableMacro.swift`. The method builds:
- Method signature (parameters, async, throws, return type)
- Method body (matcher extraction, call recording, stub lookup)

### Testing the Macro

Use `SwiftSyntaxMacrosTestSupport` in `Tests/SwiftMockkMacrosTests/`:
```swift
import SwiftSyntaxMacrosTestSupport
@testable import SwiftMockkMacros

@Test func testMockGeneration() {
    assertMacroExpansion(
        """
        @Mockable
        protocol MyProtocol {
            func method() -> String
        }
        """,
        expandedSource: """
        // Expected generated code
        """,
        macros: ["Mockable": MockableMacro.self]
    )
}
```

## Architecture Implementation Details

### Concurrency Model

- **CallRecorder**: Uses `NSLock` for thread-safe synchronous recording
- **RecordingContext**: Uses `NSLock` for mode management
- **StubbingRegistry**: Uses `NSLock` for stub storage
- **MatcherRegistry**: Uses `NSLock` for matcher storage
- All registries are classes marked `@unchecked Sendable` with proper locking

### Generated Mock Method Implementation

Generated mock methods follow this pattern:
```swift
public func methodName(args) -> ReturnType {
    // 1. Extract any registered matchers
    let matchers = MatcherRegistry.shared.extractMatchers()
    let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)

    // 2. Create a MethodCall representing this invocation
    let call = MethodCall(mockId: _mockId, name: "methodName", args: [args], matchMode: matchMode)

    // 3. Record the call
    _recorder.record(call)

    // 4. Check recording mode and return early if in stubbing/verifying mode
    let mode = RecordingContext.shared.getCurrentMode()
    if mode == .stubbing || mode == .verifying {
        // Return uninitialized memory - safe because value is never actually used
        let size = MemoryLayout<ReturnType>.size
        let alignment = MemoryLayout<ReturnType>.alignment
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: alignment)
        defer { ptr.deallocate() }
        return ptr.load(as: ReturnType.self)
    }

    // 5. Look up and return stubbed value
    return try! StubbingRegistry.shared.getStub(for: call)
}
```

### Why Mode Checking is Necessary

The mode check is crucial because:
1. During `every {}` stubbing, we execute the mock method to capture the call pattern
2. At this point, no stub exists yet - we're defining what the stub should be
3. Without the mode check, the method would try to look up a non-existent stub and crash
4. The returned dummy value is never actually used - it's discarded by the `every {}` function

## Result Type Support

SwiftMockk provides convenience methods for stubbing methods that return `Result<Success, Failure>`:

```swift
// Success case
await every { mock.fetch(url: any()) }.returnsSuccess(data, failureType: NetworkError.self)

// Failure case
await every { mock.fetch(url: any()) }.returnsFailure(NetworkError.timeout, successType: Data.self)

// Explicit construction still works
await every { mock.fetch(url: "test") }.returns(.success(data))
```

**Implementation**: The `Stubbing` class provides `returnsSuccess` and `returnsFailure` methods that construct Result values internally. Type parameters are required due to Swift's type inference limitations.

## Typed Throws Support

SwiftMockk supports Swift 6's typed throws syntax (`throws(ErrorType)`):

```swift
@Mockable
protocol UserService {
    func getUser(id: String) throws(UserError) -> User
    func fetchUsers() async throws(UserError) -> [User]
}
```

**Implementation Details**:
- The macro detects typed throws using `throwsClause.type` from swift-syntax 600.0.0+
- Generated mocks preserve the typed throws signature
- Special stub helpers (`_mockGetTypedStub`, `_mockGetTypedAsyncStub`, `_mockExecuteTypedThrowingStub`) are used for typed throws
- These helpers use `fatalError()` when no stub is found, instead of throwing `MockError.noStub`
- User-provided errors from stubs are cast to the specific error type using `as!`

**Why fatal error for missing stubs**: Swift's typed throws means a method can ONLY throw the specified error type. It cannot throw `MockError`. Therefore, typed throws methods MUST be stubbed before use.

## Known Limitations

1. **Generics**: Basic support, but complex generic constraints may not work
2. **Relaxed mocks with complex types**: Relaxed mode only works with primitive types (Int, String, Bool, etc.), not complex structs or classes
3. **Typed throws must be stubbed**: Unstubbed typed throws methods will `fatalError()` instead of throwing `MockError.noStub` (due to Swift's typed throws limitations)
4. **Spies**: Not implemented (cannot call through to real implementations)
5. **Classes**: Can only mock protocols, not concrete classes

## Debugging Tips

### Macro Expansion

View generated code:
```bash
swift build -Xswiftc -Xfrontend -Xswiftc -emit-macro-expansion-files
# Check .swiftpm/build/.../macro-expansions/
```

### Common Issues

1. **"No stub registered"**: Forgot to call `every {}` or pattern doesn't match
2. **Data race warnings**: Likely need `@unchecked Sendable` or actor isolation
3. **Matcher count mismatch**: Number of `any()`/`eq()` calls doesn't match parameter count
4. **Type mismatch**: Stub return type doesn't match method return type

## API Design Philosophy

- **Async by default**: All DSL functions are async due to Swift's concurrency model
- **Type-safe**: Leverage Swift's type system at compile time
- **Explicit**: Require explicit `await` keywords (Swift convention)
- **Familiar**: Mirror mockk's API where Swift's language features allow

## Dependencies

- **swift-syntax** (from: "510.0.0"): For macro implementation
- **Foundation**: For `UUID`, `NSLock`
- **Testing**: Swift Testing framework (not XCTest)

## Performance Considerations

- Mock generation happens at compile time (zero runtime cost for generation)
- Call recording uses actors (some async overhead)
- Matcher registration uses `NSLock` (minimal overhead)
- Stub lookup is O(n) where n = number of stubs for that method (could optimize with better data structures)
