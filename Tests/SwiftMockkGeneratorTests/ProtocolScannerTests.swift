import Testing
@testable import SwiftMockkCore

@Suite("ProtocolScanner Tests")
struct ProtocolScannerTests {

    @Test("Scan source with marked protocol")
    func testScanMarkedProtocol() {
        let source = """
        // swiftmockk:generate
        protocol UserService {
            func fetchUser(id: String) -> User
        }
        """

        let scanner = ProtocolScanner()
        let protocols = scanner.scanSource(source, moduleName: nil)

        #expect(protocols.count == 1)
        #expect(protocols.first?.name == "UserService")
    }

    @Test("Scan source with unmarked protocol")
    func testScanUnmarkedProtocol() {
        let source = """
        protocol UserService {
            func fetchUser(id: String) -> User
        }
        """

        let scanner = ProtocolScanner()
        let protocols = scanner.scanSource(source, moduleName: nil)

        #expect(protocols.isEmpty)
    }

    @Test("Scan source with multiple protocols, some marked")
    func testScanMixedProtocols() {
        let source = """
        // swiftmockk:generate
        protocol MarkedService {
            func doWork()
        }

        protocol UnmarkedService {
            func doOtherWork()
        }

        // swiftmockk:generate
        protocol AnotherMarkedService {
            func doMoreWork()
        }
        """

        let scanner = ProtocolScanner()
        let protocols = scanner.scanSource(source, moduleName: nil)

        #expect(protocols.count == 2)
        let names = protocols.map { $0.name }
        #expect(names.contains("MarkedService"))
        #expect(names.contains("AnotherMarkedService"))
        #expect(!names.contains("UnmarkedService"))
    }

    @Test("Scan source with marker and other comments")
    func testScanWithMixedComments() {
        let source = """
        // This is a documentation comment
        // swiftmockk:generate
        // Another comment
        protocol DocumentedService {
            func serve()
        }
        """

        let scanner = ProtocolScanner()
        let protocols = scanner.scanSource(source, moduleName: nil)

        #expect(protocols.count == 1)
        #expect(protocols.first?.name == "DocumentedService")
    }

    @Test("Parse protocol with async method")
    func testParseAsyncMethod() {
        let source = """
        // swiftmockk:generate
        protocol AsyncService {
            func fetchData() async -> Data
        }
        """

        let scanner = ProtocolScanner()
        let protocols = scanner.scanSource(source, moduleName: nil)

        #expect(protocols.count == 1)
        let proto = protocols.first!
        #expect(proto.methods.count == 1)
        #expect(proto.methods.first?.isAsync == true)
    }

    @Test("Parse protocol with throwing method")
    func testParseThrowingMethod() {
        let source = """
        // swiftmockk:generate
        protocol ThrowingService {
            func riskyOp() throws -> Int
        }
        """

        let scanner = ProtocolScanner()
        let protocols = scanner.scanSource(source, moduleName: nil)

        #expect(protocols.count == 1)
        let proto = protocols.first!
        #expect(proto.methods.first?.isThrowing == true)
    }

    @Test("Parse protocol with properties")
    func testParseProperties() {
        let source = """
        // swiftmockk:generate
        protocol PropertyService {
            var name: String { get set }
            var count: Int { get }
        }
        """

        let scanner = ProtocolScanner()
        let protocols = scanner.scanSource(source, moduleName: nil)

        #expect(protocols.count == 1)
        let proto = protocols.first!
        #expect(proto.properties.count == 2)

        let nameProp = proto.properties.first { $0.name == "name" }
        let countProp = proto.properties.first { $0.name == "count" }

        #expect(nameProp?.isGetSet == true)
        #expect(countProp?.isGetSet == false)
    }

    @Test("Parse protocol with generic parameters")
    func testParseGenericProtocol() {
        let source = """
        // swiftmockk:generate
        protocol Repository<Entity> {
            func fetch(id: String) -> Entity
        }
        """

        let scanner = ProtocolScanner()
        let protocols = scanner.scanSource(source, moduleName: nil)

        #expect(protocols.count == 1)
        let proto = protocols.first!
        #expect(proto.genericParameters == "<Entity>")
    }

    @Test("Module name is passed through")
    func testModuleName() {
        let source = """
        // swiftmockk:generate
        protocol Service {}
        """

        let scanner = ProtocolScanner()
        let protocols = scanner.scanSource(source, moduleName: "MyModule")

        #expect(protocols.first?.moduleName == "MyModule")
    }
}
