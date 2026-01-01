import ArgumentParser
import Foundation
import SwiftMockkCore
import SwiftSyntax
import SwiftParser

@main
struct SwiftMockkGenerator: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "SwiftMockkGenerator",
        abstract: "Generates mock implementations for protocols marked with // swiftmockk:generate",
        version: "1.0.0"
    )

    @Option(name: .shortAndLong, parsing: .upToNextOption, help: "Input directories to scan for protocols")
    var input: [String] = []

    @Option(name: .shortAndLong, help: "Output file path for generated mocks")
    var output: String

    @Option(name: .shortAndLong, help: "Module name to import in generated code")
    var module: String?

    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose: Bool = false

    func run() throws {
        if verbose {
            print("SwiftMockkGenerator starting...")
            print("Input directories: \(input)")
            print("Output file: \(output)")
            if let module = module {
                print("Module: \(module)")
            }
        }

        // Scan for protocols
        let scanner = ProtocolScanner()
        var allProtocols: [ProtocolInfo] = []

        for inputPath in input {
            let url = URL(fileURLWithPath: inputPath)
            if verbose {
                print("Scanning: \(inputPath)")
            }

            let protocols = try scanner.scanDirectory(at: url, moduleName: module, verbose: verbose)
            allProtocols.append(contentsOf: protocols)
        }

        if verbose {
            print("Found \(allProtocols.count) protocols to mock:")
            for proto in allProtocols {
                print("  - \(proto.name)")
            }
        }

        // Generate mocks
        let generator = MockGenerator()
        let generatedCode = generator.generateMocks(for: allProtocols, moduleName: module)

        // Write output
        let outputURL = URL(fileURLWithPath: output)
        try generatedCode.write(to: outputURL, atomically: true, encoding: .utf8)

        if verbose {
            print("Generated mocks written to: \(output)")
        }
    }
}
