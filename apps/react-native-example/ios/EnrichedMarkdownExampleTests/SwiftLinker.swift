// Presence-only file. The example app and the ReactNativeEnrichedMarkdown pod
// (RaTeX math bridge) contain Swift, so the XCTest bundle links Swift libraries
// and needs the Swift runtime's compatibility shims (e.g. swiftCompatibility56).
// An ObjC-only test target never triggers that linkage, which fails on CI's
// pinned Xcode with "Undefined symbol __swift_FORCE_LOAD_$_swiftCompatibility56".
// This empty Swift file makes Xcode add the Swift-runtime linkage. See
// __tests__/ios/README.md.
