import PackagePlugin
import Foundation

@main
struct SwiftMockkGeneratorPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        // Only process source module targets
        guard let sourceTarget = target as? SourceModuleTarget else {
            return []
        }

        // Find source directories from dependencies and the target itself to scan for protocols
        var inputDirectories: [Path] = []
        var inputFiles: [Path] = []

        // Scan the target's own source files (for protocols defined in test targets)
        inputDirectories.append(sourceTarget.directory)
        for file in sourceTarget.sourceFiles {
            let pathString = file.path.string
            if pathString.hasSuffix(".swift") {
                inputFiles.append(file.path)
            }
        }

        // Scan the target's dependencies for source files
        for dependency in sourceTarget.dependencies {
            switch dependency {
            case .target(let depTarget):
                if let sourceModule = depTarget as? SourceModuleTarget {
                    inputDirectories.append(sourceModule.directory)
                    // Collect all Swift source files as inputs for incremental builds
                    for file in sourceModule.sourceFiles {
                        let pathString = file.path.string
                        if pathString.hasSuffix(".swift") {
                            inputFiles.append(file.path)
                        }
                    }
                }
            case .product:
                // Skip external product dependencies
                break
            @unknown default:
                break
            }
        }

        // If no source files to scan, return empty
        guard !inputDirectories.isEmpty else {
            Diagnostics.remark("SwiftMockkGeneratorPlugin: No source files found to scan for protocols")
            return []
        }

        // Get the generator executable
        let generator = try context.tool(named: "SwiftMockkGenerator")

        // Output file in the plugin's working directory
        let outputFile = context.pluginWorkDirectory.appending("GeneratedMocks.swift")

        // Determine the module name from the first dependency
        // This assumes the test target depends on the main target
        var moduleName: String?
        for dependency in sourceTarget.dependencies {
            if case .target(let depTarget) = dependency {
                moduleName = depTarget.name
                break
            }
        }

        // Build arguments
        var arguments: [String] = []

        // Add input directories
        arguments.append("--input")
        arguments.append(contentsOf: inputDirectories.map { $0.string })

        // Add output file
        arguments.append("--output")
        arguments.append(outputFile.string)

        // Add module name if available
        if let moduleName = moduleName {
            arguments.append("--module")
            arguments.append(moduleName)
        }

        return [
            .buildCommand(
                displayName: "Generate SwiftMockk Mocks",
                executable: generator.path,
                arguments: arguments,
                inputFiles: inputFiles,
                outputFiles: [outputFile]
            )
        ]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension SwiftMockkGeneratorPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        // Get the generator executable
        let generator = try context.tool(named: "SwiftMockkGenerator")

        // Output file in the plugin's working directory
        let outputFile = context.pluginWorkDirectory.appending("GeneratedMocks.swift")

        // For Xcode projects, we need to scan the project's source files
        // Get input files from the target's source files
        var inputFiles: [Path] = []
        var inputDirectories: Set<String> = []

        for file in target.inputFiles {
            let pathString = file.path.string
            if pathString.hasSuffix(".swift") {
                inputFiles.append(file.path)
                // Get the directory containing this file
                let dir = file.path.removingLastComponent()
                inputDirectories.insert(dir.string)
            }
        }

        guard !inputDirectories.isEmpty else {
            Diagnostics.remark("SwiftMockkGeneratorPlugin: No Swift source files found")
            return []
        }

        // Build arguments
        var arguments: [String] = ["--input"]
        arguments.append(contentsOf: inputDirectories)
        arguments.append("--output")
        arguments.append(outputFile.string)

        // Try to determine module name from target
        arguments.append("--module")
        arguments.append(target.displayName)

        return [
            .buildCommand(
                displayName: "Generate SwiftMockk Mocks",
                executable: generator.path,
                arguments: arguments,
                inputFiles: inputFiles,
                outputFiles: [outputFile]
            )
        ]
    }
}
#endif
