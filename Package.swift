// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SwiftMockk",
    platforms: [.macOS(.v12), .iOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftMockk",
            targets: ["SwiftMockk"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax", from: "510.0.0")
    ],
    targets: [
        // Macro implementation target
        .macro(
            name: "SwiftMockkMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),

        // Main library target
        .target(
            name: "SwiftMockk",
            dependencies: ["SwiftMockkMacros"]
        ),

        // Test targets
        .testTarget(
            name: "SwiftMockkTests",
            dependencies: ["SwiftMockk"]
        ),
        .testTarget(
            name: "SwiftMockkMacrosTests",
            dependencies: [
                "SwiftMockkMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
            ]
        ),
    ]
)
