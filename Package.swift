// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EnrichedMarkdown",
    platforms: [.iOS(.v15), .macOS(.v14)],
    products: [
        .library(name: "EnrichedMarkdown", targets: ["EnrichedMarkdown"]),
    ],
    targets: [
        .target(
            name: "EnrichedMarkdownCore",
            path: "packages/core/cpp",
            sources: ["md4c", "parser"],
            publicHeadersPath: "parser",
            cSettings: [
                .define("MD4C_USE_UTF8", to: "1"),
            ],
            cxxSettings: [
                .headerSearchPath("md4c"),
                .headerSearchPath("parser"),
            ]
        ),
        .target(
            name: "EnrichedMarkdownCppShim",
            dependencies: ["EnrichedMarkdownCore"],
            path: "packages/ios-enriched-markdown/cpp",
            publicHeadersPath: ".",
            cxxSettings: [
                .headerSearchPath("../../core/cpp/md4c"),
                .headerSearchPath("../../core/cpp/parser"),
                .define("MD4C_USE_UTF8", to: "1"),
            ]
        ),
        .target(
            name: "EnrichedMarkdown",
            dependencies: ["EnrichedMarkdownCppShim"],
            path: "packages/ios-enriched-markdown/Sources/EnrichedMarkdown"
        ),
        .testTarget(
            name: "EnrichedMarkdownTests",
            dependencies: ["EnrichedMarkdown"],
            path: "packages/ios-enriched-markdown/Tests/EnrichedMarkdownTests"
        ),
    ]
)
