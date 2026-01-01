# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftMockk is a Swift mocking library inspired by Kotlin's mockk. It uses a build-phase code generator to create mock implementations from protocols marked with `// swiftmockk:generate`, providing a fluent DSL for stubbing and verification. SwiftMockk is designed to be a **test-target only dependency** - no need to add it to your main target.

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

SwiftMockk uses a **three-layer architecture**:

1. **Generator Layer** (`Sources/SwiftMockkCore/` + `Sources/SwiftMockkGenerator/`): Parses protocols and generates mock classes at build time
2. **Plugin Layer** (`Plugins/SwiftMockkGeneratorPlugin/`): SPM build tool plugin that runs the generator during compilation
3. **Runtime Layer** (`Sources/SwiftMockk/`): Provides DSL, call recording, and stub management

### Why Build-Phase Generation

Unlike Kotlin's mockk (which uses JVM bytecode manipulation), Swift uses static dispatch and cannot intercept method calls at runtime. SwiftMockk uses build-phase code generation to create explicit mock implementations that record and stub calls. This approach:
- Keeps SwiftMockk as a test-target only dependency
- Requires no special build settings in the main target
- Works with standard SPM build tool plugins

## Directory Structure

```
Sources/
├── SwiftMockk/                    # Runtime library (public API)
│   ├── SwiftMockk.swift          # Main exports, helper functions, mockk()
│   ├── DSL/
│   │   ├── Every.swift           # every() function for stubbing
│   │   ├── Verify.swift          # verify() functions and VerificationMode
│   │   └── Stubbing.swift        # Stubbing builder class
│   ├── Matchers/
│   │   ├── Matchers.swift        # any(), eq(), match() functions
│   │   └── MatcherRegistry.swift # Thread-safe matcher storage
│   ├── Recording/
│   │   ├── CallRecorder.swift    # Records method invocations per mock
│   │   ├── MethodCall.swift      # Represents a method call
│   │   ├── RecordingContext.swift # Global recording mode state
│   │   └── StubbingRegistry.swift # Stores stubs globally by mock ID
│   ├── Registry/
│   │   └── MockRegistry.swift    # MockFactory and MockRegistry for mockk()
│   └── Protocols/
│       └── Mockable.swift        # Base protocol for generated mocks
│
├── SwiftMockkCore/               # Shared code generation logic
│   ├── ProtocolInfo.swift        # Data structures for parsed protocols
│   ├── ProtocolParser.swift      # Parses SwiftSyntax into ProtocolInfo
│   ├── ProtocolScanner.swift     # Scans for // swiftmockk:generate markers
│   └── MockGenerator.swift       # Generates mock class source code
│
└── SwiftMockkGenerator/          # CLI executable
    └── SwiftMockkGenerator.swift # ArgumentParser command

Plugins/
└── SwiftMockkGeneratorPlugin/
    └── SwiftMockkGeneratorPlugin.swift  # SPM build tool plugin

Tests/
├── SwiftMockkTests/              # Runtime library tests
├── SwiftMockkCoreTests/          # Core module tests
└── SwiftMockkGeneratorTests/     # Generator tests
```

## Key Technical Details

### Swift Concurrency and Thread Safety

- **All DSL functions are async**: `every {}` and `verify {}` are async for consistency and future extensibility
- **Synchronous locking**: All registries (`RecordingContext`, `CallRecorder`, `StubbingRegistry`, `MatcherRegistry`) use `NSLock` for thread-safe synchronous access
- **No actors**: While actors were considered, the implementation uses classes with `@unchecked Sendable` and explicit locking to avoid async context restrictions
- **Recording mode**: Global `RecordingContext.shared` manages whether we're in normal/stubbing/verifying mode

### How Mock Generation Works

1. User marks protocol with `// swiftmockk:generate` comment (no imports needed in main target)
2. SPM build tool plugin runs before test target compilation
3. `SwiftMockkGenerator` executable scans source directories for marked protocols
4. `ProtocolScanner` uses SwiftSyntax to find protocols with the marker comment
5. `ProtocolParser` parses protocol declarations into `ProtocolInfo` structs
6. `MockGenerator` generates `Mock{ProtocolName}` class source code
7. Generated `GeneratedMocks.swift` is included in test target compilation

**Generated mock example:**
```swift
public class MockUserService: UserService, Mockable {
    public let _mockId = UUID().uuidString
    public var _recorder: CallRecorder { CallRecorder.shared(for: _mockId) }
    public var _mockMode: MockMode = .strict

    public init(mode: MockMode = .strict) { _mockMode = mode }

    public func fetchUser(id: String) async throws -> User {
        let matchers = MatcherRegistry.shared.extractMatchers()
        let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
        let call = MethodCall(mockId: _mockId, name: "fetchUser", args: [id], matchMode: matchMode)
        _recorder.record(call)
        return try await _mockGetAsyncStub(for: call, mockMode: _mockMode)
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

### mockk() Factory Function

SwiftMockk provides a Kotlin-style `mockk()` function for creating mocks:

```swift
let mock = mockk(UserService.self)
let relaxedMock = mockk(UserService.self, mode: .relaxed)
```

**Architecture:**

```
Generated Code                    Runtime
--------------                    -------
MockUserService registers  --->   MockRegistry stores factory
itself via init                        |
                                       v
mockk(UserService.self)    --->   MockRegistry.create() returns mock
```

**Key components (`Sources/SwiftMockk/Registry/MockRegistry.swift`):**

- `MockFactory` - Type-erased factory struct that wraps `(MockMode) -> Mockable` closures
- `MockRegistry` - Singleton registry mapping `ObjectIdentifier(Protocol.Type)` to factories
- `MockRegistryError` - Error enum for `.notRegistered` and `.typeMismatch`

**How auto-registration works:**

1. Each generated non-generic mock has a static `_registerOnce` property:
   ```swift
   private static let _registerOnce: Void = {
       MockRegistry.shared.register(UserService.self) { mode in
           MockUserService(mode: mode)
       }
   }()
   ```

2. The init method triggers registration of ALL mocks in the file:
   ```swift
   public init(mode: MockMode = .strict) {
       _ = _autoRegister  // File-level constant that calls _registerAllMocks()
       _mockMode = mode
   }
   ```

3. `_registerAllMocks()` function at file end calls `ensureRegistered()` on each mock

**Why generic protocols don't support mockk():**
- Generic protocols like `Repository<Entity>` require type parameters
- Can't create a factory that works for all type combinations
- Must use direct instantiation: `MockRepository<User>()`

**Public API:**
- `mockk<T>(_ protocolType: T.Type, mode: MockMode = .strict) -> T` - fatalError on failure
- `tryMockk<T>(_ protocolType: T.Type, mode: MockMode = .strict) throws -> T` - throws MockRegistryError

### Property Mocking

Properties in protocols are fully supported. The generator creates:
- Backing storage (`_propertyName`) for each property
- Getter that records calls and looks up stubs
- Setter (for get/set properties) that records calls and updates backing storage

**Property access is recorded as method calls:**
- Getter: `get_propertyName`
- Setter: `set_propertyName`

**Example:**
```swift
// swiftmockk:generate
protocol Service {
    var name: String { get set }
    var count: Int { get }
}

let mock = MockService()
await every { mock.name }.returns("Test")
await every { mock.count }.returns(42)
```

### Order Verification

Two verification functions:

1. **`verifyOrder`**: Verifies calls appear in the specified order, but not necessarily consecutively
   - Example: If actual calls are [A, X, B, Y, C], verifying [A, B, C] passes

2. **`verifySequence`**: Verifies calls appear as an exact consecutive sequence
   - Example: Actual calls must contain [A, B, C] as a consecutive subsequence

**Implementation:**
- Both functions use a `CallCollector` to capture expected calls during verification mode
- `verifyOrder` uses a two-pointer algorithm to find calls in order
- `verifySequence` checks all possible starting positions for the sequence

### Relaxed Mocks

Mocks can be created in "relaxed" mode where unstubbed methods return default values instead of throwing:

```swift
let mock = MockService(mode: .relaxed)  // Default is .strict
```

**How it works:**
- Each mock has a `_mockMode: MockMode` property
- Stub lookup helpers check the mode after failing to find a stub
- In relaxed mode, `_mockDummyValue()` is called to return a default value
- **Limitation**: Only works for primitive types (Int, String, Bool, etc.)

### Result Type Support

SwiftMockk provides convenience DSL methods for stubbing methods that return `Result<Success, Failure>`:

**DSL methods (in `Stubbing.swift`):**
- `returnsSuccess<Success, Failure: Error>(_ value: Success, failureType: Failure.Type)`
- `returnsFailure<Success, Failure: Error>(_ error: Failure, successType: Success.Type)`

**Example:**
```swift
// swiftmockk:generate
protocol NetworkService {
    func fetch(url: String) -> Result<Data, NetworkError>
}

let mock = MockNetworkService()
await every { mock.fetch(url: any()) }.returnsSuccess(data, failureType: NetworkError.self)
await every { mock.fetch(url: any()) }.returnsFailure(NetworkError.timeout, successType: Data.self)
```

### Typed Throws Support

SwiftMockk supports Swift 6's typed throws syntax `throws(ErrorType)` in protocol methods.

**Generator implementation (`MockGenerator.swift`):**
- Detects typed throws from `ProtocolInfo.MethodInfo.throwsType`
- Generated methods preserve the typed throws clause in their signature
- Uses special stub helpers for typed throws methods

**Example protocol:**
```swift
// swiftmockk:generate
protocol UserService {
    func getUser(id: String) throws(UserError) -> User
    func updateUser(_ user: User) throws(UserError)
}
```

**Key design decisions:**
- No runtime type validation needed - Swift's type system enforces correctness at compile time
- Typed errors conform to `Error`, so existing stub system works without changes
- `.throws()` DSL method works naturally with typed throws
- Stub storage remains type-erased (`Error`), but method signatures are type-safe

**Limitations:**
- Requires Swift 6+ language mode
- Typed throws methods MUST be stubbed (will `fatalError()` if not stubbed)

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

Modify `MockGenerator.swift` in `Sources/SwiftMockkCore/`. The generator builds:
- Method signature (parameters, async, throws, return type)
- Method body (matcher extraction, call recording, stub lookup)

### Testing the Generator

Tests are in `Tests/SwiftMockkCoreTests/` and `Tests/SwiftMockkGeneratorTests/`:
```swift
import Testing
@testable import SwiftMockkCore

@Test func testMockGeneration() {
    let info = ProtocolInfo(
        name: "MyProtocol",
        methods: [MethodInfo(name: "method", returnType: "String", ...)],
        ...
    )
    let generator = MockGenerator()
    let source = generator.generate(for: info)
    // Assert expected output
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

    // 4. Look up and return stubbed value (mode checking is in helper functions)
    return try! _mockGetStub(for: call, mockMode: _mockMode)
}
```

### Why Mode Checking is Necessary

The mode check (in `_mockGetStub` and similar helpers) is crucial because:
1. During `every {}` stubbing, we execute the mock method to capture the call pattern
2. At this point, no stub exists yet - we're defining what the stub should be
3. Without the mode check, the method would try to look up a non-existent stub and crash
4. The returned dummy value is never actually used - it's discarded by the `every {}` function

## Generics Support

SwiftMockk provides comprehensive support for generics in protocols:

### Generic Methods

Methods with type parameters are fully supported, including complex constraints and where clauses:

```swift
// swiftmockk:generate
protocol Repository {
    func fetch<T: Decodable>() async throws -> T
    func process<T>(_ data: T) throws -> String where T: Codable & Sendable
}

let mock = MockRepository()
await every { try await mock.fetch() as User }.returns(testUser)
```

### Generic Protocols

Protocols with primary associated types (Swift 5.7+) or traditional associated types are supported:

```swift
// swiftmockk:generate
protocol Repository<Entity> {
    func fetch(id: String) async throws -> Entity
    func save(_ entity: Entity) async throws
}

let userRepo = MockRepository<User>()
await every { try await userRepo.fetch(id: "123") }.returns(testUser)
```

### Associated Types

Traditional `associatedtype` declarations are automatically converted to generic parameters:

```swift
// swiftmockk:generate
protocol Container {
    associatedtype Item
    func add(_ item: Item)
    func getAll() -> [Item]
}

let container = MockContainer<String>()
await every { container.getAll() }.returns(["Hello", "World"])
```

### Variadic Generics (Swift 5.9+)

Variadic generics with parameter packs are supported:

```swift
// swiftmockk:generate
protocol VariadicProcessor {
    func process<each T>(_ values: repeat each T) -> (repeat each T)
}

let processor = MockVariadicProcessor()
await every { processor.process("Hello", 42, true) }.returns(("Hello", 42, true))
```

**Note**: Parameter pack arguments aren't recorded individually due to type erasure limitations, but stubbing and verification by method name work correctly.

## Known Limitations

1. **Generic protocols and mockk()**: Generic protocols (those with associated types or type parameters) cannot use `mockk()` - use direct instantiation instead: `MockRepository<User>()`
2. **Relaxed mocks with complex types**: Relaxed mode only works with primitive types (Int, String, Bool, etc.), not complex structs or classes
3. **Typed throws must be stubbed**: Unstubbed typed throws methods will `fatalError()` instead of throwing `MockError.noStub` (due to Swift's typed throws limitations)
4. **Variadic generics argument recording**: Methods with parameter packs don't record individual arguments (due to type erasure limitations), but stubbing and verification by method name still work
5. **Spies**: Not implemented (cannot call through to real implementations)
6. **Classes**: Can only mock protocols, not concrete classes

## Debugging Tips

### View Generated Mocks

Check the generated mocks in the build directory:
```bash
find .build -name "GeneratedMocks.swift" -exec cat {} \;
```

### Run Generator Manually

```bash
swift build --product SwiftMockkGenerator
./.build/debug/SwiftMockkGenerator --input Sources/YourModule --output /tmp/mocks.swift --verbose
```

### Common Issues

1. **"No stub registered"**: Forgot to call `every {}` or pattern doesn't match
2. **"cannot find 'MockX' in scope"**: Generator didn't find the protocol - check the `// swiftmockk:generate` marker
3. **Data race warnings**: Likely need `@unchecked Sendable` or actor isolation
4. **Matcher count mismatch**: Number of `any()`/`eq()` calls doesn't match parameter count
5. **Type mismatch**: Stub return type doesn't match method return type

## API Design Philosophy

- **Async by default**: All DSL functions are async due to Swift's concurrency model
- **Type-safe**: Leverage Swift's type system at compile time
- **Explicit**: Require explicit `await` keywords (Swift convention)
- **Familiar**: Mirror mockk's API where Swift's language features allow
- **Test-target only**: No impact on main target or production code

## Dependencies

- **swift-syntax** (from: "600.0.0"): For protocol parsing in the generator
- **swift-argument-parser** (from: "1.2.0"): For CLI argument parsing
- **Foundation**: For `UUID`, `NSLock`
- **Testing**: Swift Testing framework (not XCTest)

## Performance Considerations

- Mock generation happens at build time (zero runtime cost for generation)
- Call recording uses `NSLock` (minimal overhead)
- Matcher registration uses `NSLock` (minimal overhead)
- Stub lookup is O(n) where n = number of stubs for that method (could optimize with better data structures)
