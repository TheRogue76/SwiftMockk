// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftMockk",
    platforms: [.macOS(.v12), .iOS(.v13)],
    products: [
        // Main library for runtime support
        .library(
            name: "SwiftMockk",
            targets: ["SwiftMockk"]
        ),
        // Build tool plugin for generating mocks from marked protocols
        .plugin(
            name: "SwiftMockkGeneratorPlugin",
            targets: ["SwiftMockkGeneratorPlugin"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax", from: "600.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
    ],
    targets: [
        // MARK: - Core Module (shared code generation logic)

        .target(
            name: "SwiftMockkCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        // MARK: - Main Library (runtime support only, no macros)

        .target(
            name: "SwiftMockk"
        ),

        // MARK: - Generator Executable

        .executableTarget(
            name: "SwiftMockkGenerator",
            dependencies: [
                "SwiftMockkCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        // MARK: - Build Tool Plugin

        .plugin(
            name: "SwiftMockkGeneratorPlugin",
            capability: .buildTool(),
            dependencies: ["SwiftMockkGenerator"]
        ),

        // MARK: - Test Targets

        .testTarget(
            name: "SwiftMockkTests",
            dependencies: ["SwiftMockk"],
            plugins: [.plugin(name: "SwiftMockkGeneratorPlugin")]
        ),
        .testTarget(
            name: "SwiftMockkCoreTests",
            dependencies: [
                "SwiftMockkCore",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "SwiftMockkGeneratorTests",
            dependencies: [
                "SwiftMockkCore",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
    ]
)
