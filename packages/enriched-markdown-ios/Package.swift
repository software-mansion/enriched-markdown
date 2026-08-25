// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EnrichedMarkdown",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "EnrichedMarkdown", targets: ["EnrichedMarkdown"])
    ],
    targets: [
        .target(
            name: "EnrichedMarkdownCore",
            path: "core",
            sources: ["md4c", "parser"],
            publicHeadersPath: "parser",
            cSettings: [
                .define("MD4C_USE_UTF8", to: "1")
            ],
            cxxSettings: [
                .headerSearchPath("md4c"),
                .headerSearchPath("parser")
            ]
        ),
        .target(
            name: "EnrichedMarkdownCppShim",
            dependencies: ["EnrichedMarkdownCore"],
            path: "cpp",
            publicHeadersPath: ".",
            cxxSettings: [
                .headerSearchPath("../core/md4c"),
                .headerSearchPath("../core/parser"),
                .define("MD4C_USE_UTF8", to: "1")
            ]
        ),
        .target(
            name: "EnrichedMarkdown",
            dependencies: ["EnrichedMarkdownCppShim"],
            path: "Sources/EnrichedMarkdown"
        ),
        .testTarget(
            name: "EnrichedMarkdownTests",
            dependencies: ["EnrichedMarkdown"],
            path: "Tests/EnrichedMarkdownTests"
        )
    ]
)
