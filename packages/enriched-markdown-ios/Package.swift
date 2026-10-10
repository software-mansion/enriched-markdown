// swift-tools-version: 5.9
import PackageDescription

let highlightGrammars: [(name: String, hasScanner: Bool)] = [
    ("json", false), ("html", true), ("css", true), ("markdown", true), ("yaml", true),
    ("go", false), ("java", false), ("javascript", true), ("python", true), ("c", false),
    ("rust", true), ("bash", true), ("typescript", true), ("tsx", true)
]

let package = Package(
    name: "EnrichedMarkdown",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "EnrichedMarkdown", targets: ["EnrichedMarkdown"]),
        // Optional LaTeX math rendering — links the prebuilt RaTeX engine
        // (~3-5 MB of app size); without it, `$…$` stays plain text.
        .library(name: "EnrichedMarkdownLaTeX", targets: ["EnrichedMarkdownLaTeX"]),
        // Optional syntax highlighting of fenced code blocks — compiles
        // tree-sitter and its grammars (~8 MB of app size).
        .library(name: "EnrichedMarkdownSyntaxHighlighting", targets: ["EnrichedMarkdownSyntaxHighlighting"])
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
        // Prebuilt RaTeX layout engine (Rust behind a C FFI; imports as
        // RaTeXFFI), pinned to the same release and sha256 as the monorepo's
        // vendor/ratex-version.json. Every consumer's resolve hits this URL,
        // so it should move under software-mansion-labs control before release.
        .binaryTarget(
            name: "RaTeX",
            url: "https://github.com/erweixin/RaTeX/releases/download/v0.1.14/RaTeX.xcframework.zip",
            checksum: "16b84a5e9b9f80ed4910c490f96dda047662e9bdd0934817ecf4464cf02581f2"
        ),
        // Vendor/'s upstream RaTeX sources (see Vendor/LICENSE) and the KaTeX
        // Fonts are symlinks into the RN package's vendored files —
        // materialized by `yarn install`, pinned in vendor/ratex-version.json,
        // and dereferenced into real files when the standalone repo is synced.
        .target(
            name: "EnrichedMarkdownLaTeX",
            dependencies: ["EnrichedMarkdown", "RaTeX"],
            path: "Sources/EnrichedMarkdownLaTeX",
            exclude: ["Vendor/LICENSE"],
            resources: [.copy("Fonts")]
        ),
        // Symlinks into packages/core/cpp/highlight, restored by `node vendor/vendor-grammars.mjs`.
        .target(
            name: "EnrichedMarkdownTreeSitter",
            path: "highlight",
            sources: [
                "SwiftHighlightShim.cpp",
                "seam/CodeBlockHighlighter.cpp",
                "seam/CodeBlockLanguages.cpp",
                "generated/generated_registry.cpp",
                "tree-sitter/src/lib.c"
            ] + highlightGrammars.flatMap { grammar in
                (grammar.hasScanner ? ["parser.c", "scanner.c"] : ["parser.c"]).map { "grammars/\(grammar.name)/\($0)" }
            },
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("tree-sitter/include")
            ],
            cxxSettings: [
                .headerSearchPath("seam"),
                .headerSearchPath("generated"),
                .headerSearchPath("tree-sitter/include"),
                .define("ENRICHED_MARKDOWN_CODE_HIGHLIGHT", to: "1")
            ]
        ),
        .target(
            name: "EnrichedMarkdownSyntaxHighlighting",
            dependencies: ["EnrichedMarkdown", "EnrichedMarkdownTreeSitter"],
            path: "Sources/EnrichedMarkdownSyntaxHighlighting"
        ),
        .testTarget(
            name: "EnrichedMarkdownTests",
            dependencies: ["EnrichedMarkdown"],
            path: "Tests/EnrichedMarkdownTests"
        ),
        .testTarget(
            name: "EnrichedMarkdownLaTeXTests",
            dependencies: ["EnrichedMarkdownLaTeX"],
            path: "Tests/EnrichedMarkdownLaTeXTests"
        ),
        .testTarget(
            name: "EnrichedMarkdownSyntaxHighlightingTests",
            dependencies: ["EnrichedMarkdownSyntaxHighlighting"],
            path: "Tests/EnrichedMarkdownSyntaxHighlightingTests"
        )
    ]
)
