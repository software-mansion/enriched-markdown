// swift-tools-version: 6.0
import Foundation
import PackageDescription

// SwiftPM manifest for `npx react-native spm` (React Native 0.88+); CocoaPods builds use
// ReactNativeEnrichedMarkdown.podspec. spm-plugin.js bakes the app's "enriched-markdown"
// config into this file (see the comment there for why).

let packageDirectory = URL(fileURLWithPath: Context.packageDirectory)
let packageRoot = packageDirectory.resolvingSymlinksInPath()

func readJSON(_ url: URL) -> [String: Any]? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
}

func exists(_ relativePath: String) -> Bool {
    FileManager.default.fileExists(atPath: packageRoot.appendingPathComponent(relativePath).path)
}

func isFile(_ relativePath: String) -> Bool {
    var isDirectory: ObjCBool = false
    let path = packageRoot.appendingPathComponent(relativePath).path
    return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && !isDirectory.boolValue
}

// Fallback when spm-plugin.js has not run, mainly React Native 0.87, which does not read
// swiftpmConfig: the first package.json above that is not ours, i.e. the app's.
func findAppPackageJSON() -> [String: Any] {
    var dir = packageDirectory.standardizedFileURL.deletingLastPathComponent()
    while dir.path != "/" {
        if let json = readJSON(dir.appendingPathComponent("package.json")),
           json["name"] as? String != "react-native-enriched-markdown" {
            return json
        }
        dir = dir.deletingLastPathComponent()
    }
    return [:]
}

// spm-plugin.js rewrites everything between these markers.
// BEGIN enriched-markdown baked config
let bakedConfigJSON: String? = nil
let reactNativePackagePath = "../../../../xcframeworks"
let generatedCodePackagePath = "../../../ios"
// END enriched-markdown baked config

let config: [String: Any] = {
    if let baked = bakedConfigJSON?.data(using: .utf8),
       let parsed = (try? JSONSerialization.jsonObject(with: baked)) as? [String: Any] {
        return parsed
    }
    return findAppPackageJSON()["enriched-markdown"] as? [String: Any] ?? [:]
}()

let troubleshooting = "https://github.com/software-mansion/enriched-markdown/blob/main/docs-md/NATIVE_ASSETS.md"

// MARK: - LaTeX math (RaTeX)

let mathExplicit = config["enableMath"] as? Bool
let ratexPresent = exists("ios/vendor/RaTeX.xcframework") && isFile("ios/vendor/.stamp")
if mathExplicit == true && !ratexPresent {
    fatalError("""
        [react-native-enriched-markdown] LaTeX math is enabled but the vendored RaTeX assets \
        are missing or incomplete at ios/vendor. Reinstall to fetch them: \
        `npm rebuild react-native-enriched-markdown`. To disable, set \
        "enriched-markdown".enableMath = false in your app package.json. \
        Troubleshooting: \(troubleshooting)
        """)
}
let enableMath = (mathExplicit ?? true) && ratexPresent

let ratexSlices = (try? FileManager.default.contentsOfDirectory(
    atPath: packageRoot.appendingPathComponent("ios/vendor/RaTeX.xcframework").path)) ?? []
if enableMath && ratexSlices.contains(where: { exists("ios/vendor/RaTeX.xcframework/\($0)/Headers/module.modulemap") }) {
    fatalError("""
        [react-native-enriched-markdown] ios/vendor/RaTeX.xcframework has the old header layout. \
        Re-vendor it: `yarn prepare` in this repository, or reinstall the package.
        """)
}

// MARK: - Code highlighting (tree-sitter)

let grammarManifest = ["cpp/highlight/grammar-versions.json", "../../vendor/grammar-versions.json"]
    .lazy
    .compactMap { readJSON(packageRoot.appendingPathComponent($0)) }
    .first?["grammars"] as? [String: [String: Any]] ?? [:]
let defaultLanguages = grammarManifest.filter { $0.value["default"] as? Bool == true }.keys.sorted()

let highlightExplicit = config["enableCodeHighlight"] as? Bool
let grammarsPresent = isFile("cpp/highlight/vendor/grammars/.stamp")
    && exists("cpp/highlight/vendor/guarded/generated_registry.cpp")
if highlightExplicit == true && !grammarsPresent {
    fatalError("""
        [react-native-enriched-markdown] code highlighting is enabled but the tree-sitter \
        grammars are not installed. Reinstall to fetch them: \
        `npm rebuild react-native-enriched-markdown`. To disable, set \
        "enriched-markdown".enableCodeHighlight = false in your app package.json. \
        Troubleshooting: \(troubleshooting)
        """)
}

let languages: [String] = {
    guard highlightExplicit != false, grammarsPresent else { return [] }
    guard let requested = config["codeHighlightLanguages"] as? [Any] else { return defaultLanguages }
    let langs = requested.compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
    let unknown = langs.filter { grammarManifest[$0] == nil }
    if !unknown.isEmpty {
        fatalError("""
            [react-native-enriched-markdown] unknown codeHighlightLanguages: \
            \(unknown.joined(separator: ", ")). Supported: \(grammarManifest.keys.sorted().joined(separator: ", ")).
            """)
    }
    let missing = langs.filter { !exists("cpp/highlight/vendor/grammars/\($0)/parser.c") }
    if !missing.isEmpty {
        fatalError("""
            [react-native-enriched-markdown] grammars not installed: \(missing.joined(separator: ", ")). \
            Reinstall to fetch them: `npm rebuild react-native-enriched-markdown`.
            """)
    }
    return Array(Set(langs)).sorted()
}()
let enableHighlight = !languages.isEmpty

// MARK: - Video

let enableVideo = config["enableVideo"] as? Bool ?? true

// MARK: - Build settings

// Must match the guard gen-registry.mjs --guarded writes around each grammar.
func grammarDefine(_ id: String) -> String {
    "ENRM_GRAMMAR_" + id.uppercased().replacingOccurrences(of: "[^A-Z0-9]", with: "_", options: .regularExpression)
}

var defines: [(String, String)] = [
    ("ENRMRKD_USE_UTF8", "1"),
    ("ENRICHED_MARKDOWN_MATH", enableMath ? "1" : "0"),
    ("ENRICHED_MARKDOWN_VIDEO", enableVideo ? "1" : "0"),
]
var highlightSources: [String] = []
if enableHighlight {
    defines.append(("ENRICHED_MARKDOWN_CODE_HIGHLIGHT", "1"))
    defines += languages.map { (grammarDefine($0), "1") }
    highlightSources = [
        "cpp/highlight/vendor/tree-sitter/src/lib.c",
        "cpp/highlight/vendor/guarded/generated_registry.cpp",
    ] + languages.flatMap { lang in
        ["parser.c", "scanner.c"]
            .map { "cpp/highlight/vendor/grammars/\(lang)/\($0)" }
            .filter { exists($0) }
    }
}

// Generated by `yarn generate-spm-header-paths`; `yarn lint` fails when it is stale.
let headerSearchPaths: [String] = [
    "common",
    "ios",
    "ios/attachments",
    "ios/input",
    "ios/input/internals",
    "ios/input/styles",
    "ios/internals",
    "ios/math",
    "ios/parser",
    "ios/renderer",
    "ios/segments",
    "ios/slots",
    "ios/styles",
    "ios/turbomodule",
    "ios/utils",
    "ios/views",
    "cpp/enrmrkd",
    "cpp/parser",
    "cpp/repair",
    "cpp/highlight",
    "cpp/latex",
]
    + (enableHighlight ? ["cpp/highlight/vendor/tree-sitter/include", "cpp/highlight/vendor/guarded"] : [])

let cSettings: [CSetting] = headerSearchPaths.map { .headerSearchPath($0) }
    + defines.map { .define($0.0, to: $0.1) }
let cxxSettings: [CXXSetting] = headerSearchPaths.map { .headerSearchPath($0) }
    + defines.map { .define($0.0, to: $0.1) }
    + [
        .define("DEBUG", .when(configuration: .debug)),
        .define("NDEBUG", .when(configuration: .release)),
    ]

var mainDependencies: [Target.Dependency] = [
    .product(name: "ReactHeaders", package: "ReactNative"),
    .product(name: "ReactNativeHeaders", package: "ReactNative"),
    .product(name: "ReactNativeDependenciesHeaders", package: "ReactNative"),
    .product(name: "ReactAppHeaders", package: "React-GeneratedCode"),
]
var mathTargets: [Target] = []
if enableMath {
    mainDependencies.append("ReactNativeEnrichedMarkdownMath")
    mathTargets = [
        .binaryTarget(name: "RaTeXFFI", path: "ios/vendor/RaTeX.xcframework"),
        .target(
            name: "ReactNativeEnrichedMarkdownMath",
            dependencies: ["RaTeXFFI"],
            path: "ios",
            exclude: ["vendor/LICENSE", "vendor/RaTeX.xcframework"],
            sources: [
                "math/ENRMRaTeXBridge.swift",
                "vendor/DisplayList.swift",
                "vendor/RaTeXEngine.swift",
                "vendor/RaTeXFontLoader.swift",
                "vendor/RaTeXRenderer.swift",
            ],
            resources: [.copy("vendor/Fonts")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
}

let notSources = ["node_modules", "android", "lib", "src", "__tests__", "ios/vendor", "ios/generated", "ios/build"]
    .filter { exists($0) }

let package = Package(
    name: "ReactNativeEnrichedMarkdown",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "ReactNativeEnrichedMarkdown", targets: ["ReactNativeEnrichedMarkdown"]),
    ],
    dependencies: [
        .package(name: "ReactNative", path: reactNativePackagePath),
        .package(name: "React-GeneratedCode", path: generatedCodePackagePath),
    ],
    targets: mathTargets + [
        .target(
            name: "ReactNativeEnrichedMarkdown",
            dependencies: mainDependencies,
            path: ".",
            exclude: notSources + ["ios/math/ENRMRaTeXBridge.swift"],
            sources: [
                "ios", "common",
                "cpp/enrmrkd", "cpp/parser", "cpp/repair", "cpp/latex",
                "cpp/highlight/CodeBlockHighlighter.cpp", "cpp/highlight/CodeBlockLanguages.cpp",
            ] + highlightSources,
            publicHeadersPath: "ios/include",
            cSettings: cSettings,
            cxxSettings: cxxSettings,
            linkerSettings: [.linkedFramework("ImageIO")] + (enableVideo ? [.linkedFramework("AVKit")] : [])
        ),
    ],
    cxxLanguageStandard: .cxx20
)
