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

### Swift Concurrency and Actors

- **All DSL functions are async**: `every {}` and `verify {}` are async because they interact with actor-isolated state
- **Actor usage**: `RecordingContext`, `CallRecorder`, and `StubbingRegistry` use actors for thread safety
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

1. `every { await mock.method(args) }` enters stubbing mode
2. Executes the closure → triggers mock method
3. Mock method records call to `RecordingContext.shared`
4. `every` retrieves captured call and returns `Stubbing` builder
5. User calls `.returns(value)` on the builder
6. Stub is registered in `StubbingRegistry.shared` keyed by `(mockId, methodName)`

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

## Important Patterns and Conventions

### Sendable Compliance (Swift 6)

- Use `@unchecked Sendable` for types storing `Any` or closures: `MethodCall`, `StubBehavior`, matchers
- Use actors for mutable shared state: `RecordingContext`, `StubbingRegistry` (though StubbingRegistry is actually an actor)
- Use `NSLock` for synchronous access: `MatcherRegistry`, `CallRecorderRegistry`

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

## Known Limitations

1. **Properties**: Not yet implemented in macro generation
2. **Generics**: Basic support, but complex generic constraints may not work
3. **Order verification**: `verifyOrder()` and `verifySequence()` are stubbed but not implemented
4. **Relaxed mocks**: Not implemented (all methods must be stubbed)
5. **Spies**: Not implemented (cannot call through to real implementations)
6. **Classes**: Can only mock protocols, not concrete classes

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
