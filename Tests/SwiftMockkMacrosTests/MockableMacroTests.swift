import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import SwiftMockkMacros

let testMacros: [String: Macro.Type] = [
    "Mockable": MockableMacro.self
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
                _recorder.record(call)
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
                _recorder.record(call)
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
                _recorder.record(call)
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
                _recorder.record(call)
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
                _recorder.record(call)
                return try! await StubbingRegistry.shared.getAsyncStub(for: call)
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
                _recorder.record(call)
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
                _recorder.record(call)
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
                _recorder.record(call)
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
                _recorder.record(call)
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
                _recorder.record(call)
                return try! StubbingRegistry.shared.getStub(for: call)
            }

            public func deleteUser(id: String) throws {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "deleteUser", args: [id], matchMode: matchMode)
                _recorder.record(call)
                try StubbingRegistry.shared.executeThrowingStub(for: call)
            }

            public func updateUser(user: User) async throws -> User {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "updateUser", args: [user], matchMode: matchMode)
                _recorder.record(call)
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

// MARK: - Result Type Tests

@Test func testResultTypeMethod() {
    assertMacroExpansion(
        """
        @Mockable
        protocol NetworkService {
            func fetch(url: String) -> Result<Data, NetworkError>
        }
        """,
        expandedSource: """
        protocol NetworkService {
            func fetch(url: String) -> Result<Data, NetworkError>
        }

        public class MockNetworkService: NetworkService, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }

            public init() {
            }

            public func fetch(url: String) -> Result<Data, NetworkError> {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "fetch", args: [url], matchMode: matchMode)
                _recorder.record(call)
                return try! _mockGetStub(for: call, mockMode: _mockMode)
            }
        }
        """,
        macros: testMacros
    )
}

@Test func testAsyncResultTypeMethod() {
    assertMacroExpansion(
        """
        @Mockable
        protocol NetworkService {
            func upload(data: Data) async -> Result<Void, NetworkError>
        }
        """,
        expandedSource: """
        protocol NetworkService {
            func upload(data: Data) async -> Result<Void, NetworkError>
        }

        public class MockNetworkService: NetworkService, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }

            public init() {
            }

            public func upload(data: Data) async -> Result<Void, NetworkError> {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "upload", args: [data], matchMode: matchMode)
                _recorder.record(call)
                return try! await _mockGetAsyncStub(for: call, mockMode: _mockMode)
            }
        }
        """,
        macros: testMacros
    )
}

// MARK: - Typed Throws Tests

@Test func testTypedThrowsMethod() {
    assertMacroExpansion(
        """
        @Mockable
        protocol UserService {
            func getUser(id: String) throws(UserError) -> User
        }
        """,
        expandedSource: """
        protocol UserService {
            func getUser(id: String) throws(UserError) -> User
        }

        public class MockUserService: UserService, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }

            public init() {
            }

            public func getUser(id: String) throws(UserError) -> User {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "getUser", args: [id], matchMode: matchMode)
                _recorder.record(call)
                return try _mockGetTypedStub(for: call, mockMode: _mockMode, errorType: UserError.self)
            }
        }
        """,
        macros: testMacros
    )
}

@Test func testAsyncTypedThrowsMethod() {
    assertMacroExpansion(
        """
        @Mockable
        protocol UserService {
            func fetchUsers() async throws(UserError) -> [User]
        }
        """,
        expandedSource: """
        protocol UserService {
            func fetchUsers() async throws(UserError) -> [User]
        }

        public class MockUserService: UserService, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }

            public init() {
            }

            public func fetchUsers() async throws(UserError) -> [User] {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "fetchUsers", args: [], matchMode: matchMode)
                _recorder.record(call)
                return try await _mockGetTypedAsyncStub(for: call, mockMode: _mockMode, errorType: UserError.self)
            }
        }
        """,
        macros: testMacros
    )
}

@Test func testVoidTypedThrowsMethod() {
    assertMacroExpansion(
        """
        @Mockable
        protocol UserService {
            func updateUser(_ user: User) throws(UserError)
        }
        """,
        expandedSource: """
        protocol UserService {
            func updateUser(_ user: User) throws(UserError)
        }

        public class MockUserService: UserService, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }

            public init() {
            }

            public func updateUser(_ user: User) throws(UserError) {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "updateUser", args: [user], matchMode: matchMode)
                _recorder.record(call)
                try _mockExecuteTypedThrowingStub(for: call, errorType: UserError.self)
            }
        }
        """,
        macros: testMacros
    )
}

@Test func testMixedThrowsTypes() {
    assertMacroExpansion(
        """
        @Mockable
        protocol MixedService {
            func standardThrows() throws -> String
            func typedThrows() throws(CustomError) -> String
        }
        """,
        expandedSource: """
        protocol MixedService {
            func standardThrows() throws -> String
            func typedThrows() throws(CustomError) -> String
        }

        public class MockMixedService: MixedService, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }

            public init() {
            }

            public func standardThrows() throws -> String {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "standardThrows", args: [], matchMode: matchMode)
                _recorder.record(call)
                return try _mockGetStub(for: call, mockMode: _mockMode)
            }

            public func typedThrows() throws(CustomError) -> String {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "typedThrows", args: [], matchMode: matchMode)
                _recorder.record(call)
                return try _mockGetTypedStub(for: call, mockMode: _mockMode, errorType: CustomError.self)
            }
        }
        """,
        macros: testMacros
    )
}

// MARK: - Generic Method Tests

@Test func testGenericMethodSimple() {
    assertMacroExpansion(
        """
        @Mockable
        protocol Repository {
            func fetch<T: Decodable>() async throws -> T
        }
        """,
        expandedSource: """
        protocol Repository {
            func fetch<T: Decodable>() async throws -> T
        }

        public class MockRepository: Repository, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }
            public var _mockMode: MockMode = .strict

            public init(mode: MockMode = .strict) {
                _mockMode = mode
            }

            public func fetch<T: Decodable>() async throws -> T {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "fetch", args: [], matchMode: matchMode)
                _recorder.record(call)
                return try await _mockGetAsyncStub(for: call, mockMode: _mockMode)
            }
        }
        """,
        macros: testMacros
    )
}

@Test func testGenericMethodMultipleParams() {
    assertMacroExpansion(
        """
        @Mockable
        protocol Converter {
            func convert<Source, Target>(from: Source) -> Target
        }
        """,
        expandedSource: """
        protocol Converter {
            func convert<Source, Target>(from: Source) -> Target
        }

        public class MockConverter: Converter, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }
            public var _mockMode: MockMode = .strict

            public init(mode: MockMode = .strict) {
                _mockMode = mode
            }

            public func convert<Source, Target>(from: Source) -> Target {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "convert", args: [from], matchMode: matchMode)
                _recorder.record(call)
                return try! _mockGetStub(for: call, mockMode: _mockMode)
            }
        }
        """,
        macros: testMacros
    )
}

@Test func testGenericMethodWithWhereClause() {
    assertMacroExpansion(
        """
        @Mockable
        protocol Validator {
            func validate<T>(_ item: T) -> Bool where T: Equatable
        }
        """,
        expandedSource: """
        protocol Validator {
            func validate<T>(_ item: T) -> Bool where T: Equatable
        }

        public class MockValidator: Validator, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }
            public var _mockMode: MockMode = .strict

            public init(mode: MockMode = .strict) {
                _mockMode = mode
            }

            public func validate<T>(_ item: T) -> Bool where T: Equatable {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "validate", args: [item], matchMode: matchMode)
                _recorder.record(call)
                return try! _mockGetStub(for: call, mockMode: _mockMode)
            }
        }
        """,
        macros: testMacros
    )
}

@Test func testGenericMethodComplexConstraints() {
    assertMacroExpansion(
        """
        @Mockable
        protocol DataProcessor {
            func process<T>(_ data: T) throws -> String where T: Codable & Sendable
        }
        """,
        expandedSource: """
        protocol DataProcessor {
            func process<T>(_ data: T) throws -> String where T: Codable & Sendable
        }

        public class MockDataProcessor: DataProcessor, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }
            public var _mockMode: MockMode = .strict

            public init(mode: MockMode = .strict) {
                _mockMode = mode
            }

            public func process<T>(_ data: T) throws -> String where T: Codable & Sendable {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "process", args: [data], matchMode: matchMode)
                _recorder.record(call)
                return try _mockGetStub(for: call, mockMode: _mockMode)
            }
        }
        """,
        macros: testMacros
    )
}

// MARK: - Generic Protocol Tests

@Test func testGenericProtocolSimple() {
    assertMacroExpansion(
        """
        @Mockable
        protocol Repository<Entity> {
            func fetch(id: String) async throws -> Entity
            func save(_ entity: Entity) async throws
        }
        """,
        expandedSource: """
        protocol Repository<Entity> {
            func fetch(id: String) async throws -> Entity
            func save(_ entity: Entity) async throws
        }

        public class MockRepository<Entity>: Repository, Mockable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }
            public var _mockMode: MockMode = .strict

            public init(mode: MockMode = .strict) {
                _mockMode = mode
            }

            public func fetch(id: String) async throws -> Entity {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "fetch", args: [id], matchMode: matchMode)
                _recorder.record(call)
                return try await _mockGetAsyncStub(for: call, mockMode: _mockMode)
            }

            public func save(_ entity: Entity) async throws {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "save", args: [entity], matchMode: matchMode)
                _recorder.record(call)
                try await _mockExecuteAsyncThrowingStub(for: call)
            }
        }
        """,
        macros: testMacros
    )
}

@Test func testGenericProtocolMultipleParams() {
    assertMacroExpansion(
        """
        @Mockable
        protocol Cache<Key, Value> where Key: Hashable {
            func get(_ key: Key) -> Value?
            func set(_ key: Key, value: Value)
        }
        """,
        expandedSource: """
        protocol Cache<Key, Value> where Key: Hashable {
            func get(_ key: Key) -> Value?
            func set(_ key: Key, value: Value)
        }

        public class MockCache<Key, Value>: Cache, Mockable where Key: Hashable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }
            public var _mockMode: MockMode = .strict

            public init(mode: MockMode = .strict) {
                _mockMode = mode
            }

            public func get(_ key: Key) -> Value? {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "get", args: [key], matchMode: matchMode)
                _recorder.record(call)
                return try! _mockGetStub(for: call, mockMode: _mockMode)
            }

            public func set(_ key: Key, value: Value) {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "set", args: [key, value], matchMode: matchMode)
                _recorder.record(call)
            }
        }
        """,
        macros: testMacros
    )
}

@Test func testGenericProtocolWithConstraints() {
    assertMacroExpansion(
        """
        @Mockable
        protocol Collection<Element> where Element: Comparable {
            func add(_ element: Element)
            func sorted() -> [Element]
        }
        """,
        expandedSource: """
        protocol Collection<Element> where Element: Comparable {
            func add(_ element: Element)
            func sorted() -> [Element]
        }

        public class MockCollection<Element>: Collection, Mockable where Element: Comparable {
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }
            public var _mockMode: MockMode = .strict

            public init(mode: MockMode = .strict) {
                _mockMode = mode
            }

            public func add(_ element: Element) {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "add", args: [element], matchMode: matchMode)
                _recorder.record(call)
            }

            public func sorted() -> [Element] {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "sorted", args: [], matchMode: matchMode)
                _recorder.record(call)
                return try! _mockGetStub(for: call, mockMode: _mockMode)
            }
        }
        """,
        macros: testMacros
    )
}

// MARK: - Associated Type Tests

@Test func testAssociatedTypeSimple() {
    assertMacroExpansion(
        """
        @Mockable
        protocol Container {
            associatedtype Item
            func add(_ item: Item)
            func get(at index: Int) -> Item?
        }
        """,
        expandedSource: """
        protocol Container {
            associatedtype Item
            func add(_ item: Item)
            func get(at index: Int) -> Item?
        }

        public class MockContainer<Item>: Container, Mockable {
            public typealias Item = Item
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }
            public var _mockMode: MockMode = .strict

            public init(mode: MockMode = .strict) {
                _mockMode = mode
            }

            public func add(_ item: Item) {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "add", args: [item], matchMode: matchMode)
                _recorder.record(call)
            }

            public func get(at index: Int) -> Item? {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "get", args: [index], matchMode: matchMode)
                _recorder.record(call)
                return try! _mockGetStub(for: call, mockMode: _mockMode)
            }
        }
        """,
        macros: testMacros
    )
}

@Test func testAssociatedTypeMultiple() {
    assertMacroExpansion(
        """
        @Mockable
        protocol Mapper {
            associatedtype Input
            associatedtype Output
            func map(_ input: Input) -> Output
        }
        """,
        expandedSource: """
        protocol Mapper {
            associatedtype Input
            associatedtype Output
            func map(_ input: Input) -> Output
        }

        public class MockMapper<Input, Output>: Mapper, Mockable {
            public typealias Input = Input
            public typealias Output = Output
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }
            public var _mockMode: MockMode = .strict

            public init(mode: MockMode = .strict) {
                _mockMode = mode
            }

            public func map(_ input: Input) -> Output {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "map", args: [input], matchMode: matchMode)
                _recorder.record(call)
                return try! _mockGetStub(for: call, mockMode: _mockMode)
            }
        }
        """,
        macros: testMacros
    )
}

@Test func testAssociatedTypeWithConstraints() {
    assertMacroExpansion(
        """
        @Mockable
        protocol Sequence {
            associatedtype Element where Element: Hashable
            func forEach(_ body: (Element) -> Void)
        }
        """,
        expandedSource: """
        protocol Sequence {
            associatedtype Element where Element: Hashable
            func forEach(_ body: (Element) -> Void)
        }

        public class MockSequence<Element>: Sequence, Mockable where Element: Hashable {
            public typealias Element = Element
            public let _mockId = UUID().uuidString
            public var _recorder: CallRecorder {
                CallRecorder.shared(for: _mockId)
            }
            public var _mockMode: MockMode = .strict

            public init(mode: MockMode = .strict) {
                _mockMode = mode
            }

            public func forEach(_ body: (Element) -> Void) {
                let matchers = MatcherRegistry.shared.extractMatchers()
                let matchMode: MethodCall.MatchMode = matchers.isEmpty ? .exact : .matchers(matchers)
                let call = MethodCall(mockId: _mockId, name: "forEach", args: [body], matchMode: matchMode)
                _recorder.record(call)
            }
        }
        """,
        macros: testMacros
    )
}
