# iOS native unit tests

XCTest sources for the React Native library's Objective-C / Objective-C++ code
(`ios/**`). They run twice, once per way an app can install the library:

- CocoaPods: the app-hosted test target `EnrichedMarkdownExampleTests` in
  `apps/react-native-example`, which links the same pods as the app (via the
  Podfile `inherit! :complete` block).
- Swift Package Manager: the app-hosted test target
  `EnrichedMarkdownSpmExampleTests` in `apps/react-native-spm-example`.

Either way the tests compile against the exact code the example ships.

## Running

From the repo root:

```sh
# iOS (needs a macOS host with Xcode and an iOS Simulator)
yarn prepare

# CocoaPods
cd apps/react-native-example/ios && pod install && cd -   # also runs codegen
yarn test:ios

# Swift Package Manager (runs `react-native spm` itself)
yarn test:ios-spm
git checkout packages/react-native-enriched-markdown/Package.swift
```

`react-native spm` bakes the app's config into the library's `Package.swift`,
with absolute paths, so restore that file afterwards rather than commit it.

CI runs them in `rn-ios-build-and-tests` (CocoaPods) and
`rn-ios-spm-build-and-tests` (Swift Package Manager).

## Adding a test file to the target

Drop a `.m`/`.mm` in this directory. Nothing else is needed - no
`project.pbxproj` edit, no Xcode UI step.

Both example projects are objectVersion 54 and list sources explicitly, which
would normally mean four pbxproj entries per file and a file that silently never
ran if you forgot them. Instead each test target has a
`Generate library test sources` build phase running
`scripts/ios/generate-rn-test-sources.sh`, which globs this directory and emits
an include list that the single wired source, `ENRMLibraryTests.mm` in the
test target's directory, pulls in. That gives the iOS lanes what Gradle already
gives Android: auto-discovery.

One consequence: every file here is compiled into one translation unit, so
file-scope helpers share a namespace. Name helper classes and statics
distinctly; the `ENRM` prefix already does this for classes.

Test files import the code under test by relative path, e.g.
`#import "../../ios/attachments/ENRMLinkPillTextStorage.h"`. Those headers in
turn import their siblings unqualified, so the test target's build
configurations list every `ios/*` subdirectory in `HEADER_SEARCH_PATHS`, on top
of the C++ core and pod internals that `ReactNativeEnrichedMarkdown.podspec`
sets. `ios/vendor` is deliberately left out: sweeping it in pulls the RaTeX xcframework module maps into scope and clang rejects
the duplicate `RaTeXFFI` module definitions.

`scripts/ios/test-rn-app.sh` counts the `- (void)test` prototypes here and fails
if fewer tests than that actually ran, so a suite dropping out of the run cannot
leave the lane green.

`EnrichedMarkdownExampleTests.m` in the CocoaPods target dir is a harness
placeholder that keeps the bundle non-empty; it can stay or be removed once real
suites land here. `SwiftLinker.swift` next to it is an empty presence-only file:
the host app and the pod contain Swift, so the test bundle must link the Swift
runtime (otherwise CI's pinned Xcode fails with
`Undefined symbol __swift_FORCE_LOAD_$_swiftCompatibility56`). Keep it.
