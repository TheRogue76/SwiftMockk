import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import SwiftMockkMacros

let testMacros: [String: Macro.Type] = [
    "Mockable": MockableMacro.self,
]

// MARK: - Basic Protocol Tests

@Test func testSimpleProtocolWithNoMethods() {
    assertMacroExpansion(
        """
        @Mockable
        protocol EmptyService {
        }
        """,
        expandedSource: """
        protocol EmptyService {
        }

        public class MockEmptyService: EmptyService, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }

            public init() {
            }
        }
        """,
        macros: testMacros
    )
}

@Test func testSimpleProtocolWithOneMethod() {
    assertMacroExpansion(
        """
        @Mockable
        protocol UserService {
            func fetchUser() -> String
        }
        """,
        expandedSource: """
        protocol UserService {
            func fetchUser() -> String
        }

        public class MockUserService: UserService, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }

            public init() {
            }

            public func fetchUser() -> String {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "fetchUser", args: [], matchMode: matchMode)
                await _recorder.record(call)
                return try! StubbingRegistry.shared.getStub(for: call)
            }
        }
        """,
        macros: testMacros
    )
}

// MARK: - Method Parameter Tests

@Test func testMethodWithSingleParameter() {
    assertMacroExpansion(
        """
        @Mockable
        protocol UserService {
            func fetchUser(id: String) -> User
        }
        """,
        expandedSource: """
        protocol UserService {
            func fetchUser(id: String) -> User
        }

        public class MockUserService: UserService, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }

            public init() {
            }

            public func fetchUser(id: String) -> User {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "fetchUser", args: [id], matchMode: matchMode)
                await _recorder.record(call)
                return try! StubbingRegistry.shared.getStub(for: call)
            }
        }
        """,
        macros: testMacros
    )
}

@Test func testMethodWithMultipleParameters() {
    assertMacroExpansion(
        """
        @Mockable
        protocol UserService {
            func createUser(name: String, age: Int, email: String) -> User
        }
        """,
        expandedSource: """
        protocol UserService {
            func createUser(name: String, age: Int, email: String) -> User
        }

        public class MockUserService: UserService, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }

            public init() {
            }

            public func createUser(name: String, age: Int, email: String) -> User {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "createUser", args: [name, age, email], matchMode: matchMode)
                await _recorder.record(call)
                return try! StubbingRegistry.shared.getStub(for: call)
            }
        }
        """,
        macros: testMacros
    )
}

@Test func testMethodWithExternalAndInternalParameterNames() {
    assertMacroExpansion(
        """
        @Mockable
        protocol UserService {
            func fetchUser(withID id: String) -> User
        }
        """,
        expandedSource: """
        protocol UserService {
            func fetchUser(withID id: String) -> User
        }

        public class MockUserService: UserService, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }

            public init() {
            }

            public func fetchUser(withID id: String) -> User {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "fetchUser", args: [id], matchMode: matchMode)
                await _recorder.record(call)
                return try! StubbingRegistry.shared.getStub(for: call)
            }
        }
        """,
        macros: testMacros
    )
}

// MARK: - Async/Throws Tests

@Test func testAsyncMethod() {
    assertMacroExpansion(
        """
        @Mockable
        protocol UserService {
            func fetchUser(id: String) async -> User
        }
        """,
        expandedSource: """
        protocol UserService {
            func fetchUser(id: String) async -> User
        }

        public class MockUserService: UserService, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }

            public init() {
            }

            public func fetchUser(id: String) async -> User {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "fetchUser", args: [id], matchMode: matchMode)
                await _recorder.record(call)
                return try await StubbingRegistry.shared.getAsyncStub(for: call)
            }
        }
        """,
        macros: testMacros
    )
}

@Test func testThrowingMethod() {
    assertMacroExpansion(
        """
        @Mockable
        protocol UserService {
            func fetchUser(id: String) throws -> User
        }
        """,
        expandedSource: """
        protocol UserService {
            func fetchUser(id: String) throws -> User
        }

        public class MockUserService: UserService, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }

            public init() {
            }

            public func fetchUser(id: String) throws -> User {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "fetchUser", args: [id], matchMode: matchMode)
                await _recorder.record(call)
                return try StubbingRegistry.shared.getStub(for: call)
            }
        }
        """,
        macros: testMacros
    )
}

@Test func testAsyncThrowingMethod() {
    assertMacroExpansion(
        """
        @Mockable
        protocol UserService {
            func fetchUser(id: String) async throws -> User
        }
        """,
        expandedSource: """
        protocol UserService {
            func fetchUser(id: String) async throws -> User
        }

        public class MockUserService: UserService, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }

            public init() {
            }

            public func fetchUser(id: String) async throws -> User {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "fetchUser", args: [id], matchMode: matchMode)
                await _recorder.record(call)
                return try await StubbingRegistry.shared.getAsyncStub(for: call)
            }
        }
        """,
        macros: testMacros
    )
}

@Test func testVoidMethod() {
    assertMacroExpansion(
        """
        @Mockable
        protocol UserService {
            func deleteUser(id: String)
        }
        """,
        expandedSource: """
        protocol UserService {
            func deleteUser(id: String)
        }

        public class MockUserService: UserService, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }

            public init() {
            }

            public func deleteUser(id: String) {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "deleteUser", args: [id], matchMode: matchMode)
                await _recorder.record(call)
            }
        }
        """,
        macros: testMacros
    )
}

@Test func testVoidThrowingMethod() {
    assertMacroExpansion(
        """
        @Mockable
        protocol UserService {
            func deleteUser(id: String) throws
        }
        """,
        expandedSource: """
        protocol UserService {
            func deleteUser(id: String) throws
        }

        public class MockUserService: UserService, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }

            public init() {
            }

            public func deleteUser(id: String) throws {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "deleteUser", args: [id], matchMode: matchMode)
                await _recorder.record(call)
                try StubbingRegistry.shared.executeThrowingStub(for: call)
            }
        }
        """,
        macros: testMacros
    )
}

// MARK: - Multiple Methods

@Test func testProtocolWithMultipleMethods() {
    assertMacroExpansion(
        """
        @Mockable
        protocol UserService {
            func fetchUser(id: String) -> User
            func deleteUser(id: String) throws
            func updateUser(user: User) async throws -> User
        }
        """,
        expandedSource: """
        protocol UserService {
            func fetchUser(id: String) -> User
            func deleteUser(id: String) throws
            func updateUser(user: User) async throws -> User
        }

        public class MockUserService: UserService, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }

            public init() {
            }

            public func fetchUser(id: String) -> User {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "fetchUser", args: [id], matchMode: matchMode)
                await _recorder.record(call)
                return try! StubbingRegistry.shared.getStub(for: call)
            }

            public func deleteUser(id: String) throws {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "deleteUser", args: [id], matchMode: matchMode)
                await _recorder.record(call)
                try StubbingRegistry.shared.executeThrowingStub(for: call)
            }

            public func updateUser(user: User) async throws -> User {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "updateUser", args: [user], matchMode: matchMode)
                await _recorder.record(call)
                return try await StubbingRegistry.shared.getAsyncStub(for: call)
            }
        }
        """,
        macros: testMacros
    )
}

// MARK: - Error Tests

@Test func testMacroOnNonProtocol() {
    assertMacroExpansion(
        """
        @Mockable
        struct UserService {
            func fetchUser() -> String
        }
        """,
        expandedSource: """
        struct UserService {
            func fetchUser() -> String
        }
        """,
        diagnostics: [
            DiagnosticSpec(message: "@Mockable can only be applied to protocols", line: 1, column: 1)
        ],
        macros: testMacros
    )
}

@Test func testMacroOnClass() {
    assertMacroExpansion(
        """
        @Mockable
        class UserService {
            func fetchUser() -> String { "" }
        }
        """,
        expandedSource: """
        class UserService {
            func fetchUser() -> String { "" }
        }
        """,
        diagnostics: [
            DiagnosticSpec(message: "@Mockable can only be applied to protocols", line: 1, column: 1)
        ],
        macros: testMacros
    )
}
