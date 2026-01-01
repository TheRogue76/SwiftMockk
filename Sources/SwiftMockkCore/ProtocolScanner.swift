import Foundation
import SwiftSyntax
import SwiftParser

/// Scans source files for protocols marked with `// swiftmockk:generate`
public struct ProtocolScanner {
    /// The marker comment that indicates a protocol should have a mock generated
    public static let marker = "swiftmockk:generate"

    public init() {}

    /// Scan a directory recursively for Swift files containing marked protocols
    public func scanDirectory(at url: URL, moduleName: String?, verbose: Bool = false) throws -> [ProtocolInfo] {
        var protocols: [ProtocolInfo] = []

        let fileManager = FileManager.default

        // Handle both files and directories
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            if verbose {
                print("Warning: Path does not exist: \(url.path)")
            }
            return []
        }

        if isDirectory.boolValue {
            // Recursively scan directory
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }

            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "swift" {
                    let fileProtocols = try scanFile(at: fileURL, moduleName: moduleName, verbose: verbose)
                    protocols.append(contentsOf: fileProtocols)
                }
            }
        } else {
            // Single file
            if url.pathExtension == "swift" {
                let fileProtocols = try scanFile(at: url, moduleName: moduleName, verbose: verbose)
                protocols.append(contentsOf: fileProtocols)
            }
        }

        return protocols
    }

    /// Scan a single Swift file for marked protocols
    public func scanFile(at url: URL, moduleName: String?, verbose: Bool = false) throws -> [ProtocolInfo] {
        let source = try String(contentsOf: url, encoding: .utf8)
        return scanSource(source, moduleName: moduleName, fileName: url.lastPathComponent, verbose: verbose)
    }

    /// Scan Swift source code for marked protocols
    public func scanSource(_ source: String, moduleName: String?, fileName: String? = nil, verbose: Bool = false) -> [ProtocolInfo] {
        let sourceFile = Parser.parse(source: source)
        var protocols: [ProtocolInfo] = []
        let parser = ProtocolParser()

        // Extract imports from the source file
        let imports = extractImports(from: sourceFile)

        // Find all protocol declarations and check if they're marked
        let visitor = MarkedProtocolVisitor(source: source)
        visitor.walk(sourceFile)

        for protocolDecl in visitor.markedProtocols {
            if verbose {
                let location = fileName ?? "source"
                print("  Found marked protocol: \(protocolDecl.name.text) in \(location)")
            }
            let info = parser.parse(protocolDecl, moduleName: moduleName, imports: imports)
            protocols.append(info)
        }

        return protocols
    }

    /// Extract import statements from a source file
    private func extractImports(from sourceFile: SourceFileSyntax) -> [String] {
        var imports: [String] = []
        for statement in sourceFile.statements {
            if let importDecl = statement.item.as(ImportDeclSyntax.self) {
                let importPath = importDecl.path.map { $0.name.text }.joined(separator: ".")
                imports.append(importPath)
            }
        }
        return imports
    }
}

/// Visits the syntax tree to find protocols marked with the generator comment
private class MarkedProtocolVisitor: SyntaxVisitor {
    let source: String
    var markedProtocols: [ProtocolDeclSyntax] = []

    init(source: String) {
        self.source = source
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        // Check if this protocol is marked with the generator comment
        if isMarked(node) {
            markedProtocols.append(node)
        }
        return .skipChildren
    }

    private func isMarked(_ node: ProtocolDeclSyntax) -> Bool {
        // Check leading trivia for the marker comment
        let trivia = node.leadingTrivia

        for piece in trivia {
            switch piece {
            case .lineComment(let comment):
                if comment.contains(ProtocolScanner.marker) {
                    return true
                }
            case .blockComment(let comment):
                if comment.contains(ProtocolScanner.marker) {
                    return true
                }
            default:
                break
            }
        }

        // Also check if there's a marker on the same line before the protocol keyword
        // This handles: // swiftmockk:generate protocol Foo {}
        if let firstToken = node.firstToken(viewMode: .sourceAccurate) {
            let trivia = firstToken.leadingTrivia
            for piece in trivia {
                switch piece {
                case .lineComment(let comment):
                    if comment.contains(ProtocolScanner.marker) {
                        return true
                    }
                case .blockComment(let comment):
                    if comment.contains(ProtocolScanner.marker) {
                        return true
                    }
                default:
                    break
                }
            }
        }

        return false
    }
}
