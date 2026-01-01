import Testing
import SwiftMockkCore

@Suite("MockGenerator Tests")
struct MockGeneratorTests {

    @Test("Generate simple mock class")
    func testGenerateSimpleMock() {
        let generator = MockGenerator()

        let protocolInfo = ProtocolInfo(
            name: "SimpleService",
            methods: [
                MethodInfo(
                    name: "doSomething",
                    returnType: "String"
                )
            ]
        )

        let code = generator.generateMock(for: protocolInfo)

        #expect(code.contains("class MockSimpleService"))
        #expect(code.contains("func doSomething()"))
        #expect(code.contains(": SimpleService, Mockable"))
    }

    @Test("Generate mock with async method")
    func testGenerateAsyncMock() {
        let generator = MockGenerator()

        let protocolInfo = ProtocolInfo(
            name: "AsyncService",
            methods: [
                MethodInfo(
                    name: "fetchData",
                    isAsync: true,
                    returnType: "Data"
                )
            ]
        )

        let code = generator.generateMock(for: protocolInfo)

        #expect(code.contains("func fetchData() async"))
    }

    @Test("Generate mock with throwing method")
    func testGenerateThrowingMock() {
        let generator = MockGenerator()

        let protocolInfo = ProtocolInfo(
            name: "ThrowingService",
            methods: [
                MethodInfo(
                    name: "riskyOperation",
                    isThrowing: true,
                    throwsClause: "",
                    returnType: "Int"
                )
            ]
        )

        let code = generator.generateMock(for: protocolInfo)

        #expect(code.contains("func riskyOperation() throws"))
    }

    @Test("Generate mock with typed throws")
    func testGenerateTypedThrowsMock() {
        let generator = MockGenerator()

        let protocolInfo = ProtocolInfo(
            name: "TypedThrowsService",
            methods: [
                MethodInfo(
                    name: "getUser",
                    isThrowing: true,
                    throwsClause: "(UserError)",
                    returnType: "User"
                )
            ]
        )

        let code = generator.generateMock(for: protocolInfo)

        #expect(code.contains("func getUser() throws(UserError)"))
    }

    @Test("Generate mock with properties")
    func testGeneratePropertyMock() {
        let generator = MockGenerator()

        let protocolInfo = ProtocolInfo(
            name: "PropertyService",
            properties: [
                PropertyInfo(name: "name", type: "String", isGetSet: true),
                PropertyInfo(name: "count", type: "Int", isGetSet: false),
            ]
        )

        let code = generator.generateMock(for: protocolInfo)

        #expect(code.contains("var name: String"))
        #expect(code.contains("var count: Int"))
        #expect(code.contains("get_name"))
        #expect(code.contains("set_name"))
        #expect(code.contains("get_count"))
    }

    @Test("Generate mock with generic parameters")
    func testGenerateGenericMock() {
        let generator = MockGenerator()

        let protocolInfo = ProtocolInfo(
            name: "Repository",
            genericParameters: "<Entity>",
            methods: [
                MethodInfo(
                    name: "fetch",
                    parameters: [
                        ParameterInfo(externalName: "id", internalName: "id", type: "String")
                    ],
                    returnType: "Entity"
                )
            ]
        )

        let code = generator.generateMock(for: protocolInfo)

        #expect(code.contains("class MockRepository<Entity>"))
        #expect(code.contains(": Repository, Mockable"))
    }

    @Test("Generate multiple mocks")
    func testGenerateMultipleMocks() {
        let generator = MockGenerator()

        let protocols = [
            ProtocolInfo(name: "ServiceA"),
            ProtocolInfo(name: "ServiceB"),
        ]

        let code = generator.generateMocks(for: protocols, moduleName: "MyApp")

        #expect(code.contains("class MockServiceA"))
        #expect(code.contains("class MockServiceB"))
        #expect(code.contains("@testable import MyApp"))
        #expect(code.contains("import SwiftMockk"))
    }
}
