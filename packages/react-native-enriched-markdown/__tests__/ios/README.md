# iOS native unit tests

XCTest sources for the React Native library's Objective-C / Objective-C++ code
(`ios/**`). They run in the example app's app-hosted test target
`EnrichedMarkdownExampleTests`, which links the same pods as the app (via the
Podfile `inherit! :complete` block), so tests compile against the exact code the
example ships.

## Running

From the repo root:

```sh
# iOS (needs a macOS host with Xcode + a booted iOS Simulator)
yarn prepare                 # generate codegen the pod needs
cd apps/react-native-example/ios && pod install && cd -
yarn turbo run test:ios --filter=react-native-enriched-markdown-example
# runs apps/react-native-example/scripts/test-ios.sh, which resolves a simulator
# (IOS_SIMULATOR_UDID -> a booted sim -> first available iPhone) and calls:
#   xcodebuild test -workspace apps/react-native-example/ios/EnrichedMarkdownExample.xcworkspace \
#     -scheme EnrichedMarkdownExample \
#     -destination "platform=iOS Simulator,id=<resolved-udid>"
```

CI runs this in the `rn-ios-unit-tests` job.

## Adding a test file to the target

Drop a `.m`/`.mm` in this directory. Nothing else is needed - no
`project.pbxproj` edit, no Xcode UI step.

`EnrichedMarkdownExample.xcodeproj` is objectVersion 54 and lists sources
explicitly, which would normally mean four pbxproj entries per file and a file
that silently never ran if you forgot them. Instead the test target has a
`Generate library test sources` build phase running
`apps/react-native-example/scripts/generate-ios-test-sources.sh`, which globs
this directory and emits an include list that the single wired source,
`EnrichedMarkdownExampleTests/ENRMLibraryTests.mm`, pulls in. That gives the iOS
lane what Gradle already gives Android: auto-discovery.

One consequence: every file here is compiled into one translation unit, so
file-scope helpers share a namespace. Name helper classes and statics
distinctly; the `ENRM` prefix already does this for classes.

Test files import the code under test by relative path, e.g.
`#import "../../ios/attachments/ENRMLinkPillTextStorage.h"`. Those headers in
turn import their siblings unqualified, so the test target's build
configurations list every `ios/*` subdirectory in `HEADER_SEARCH_PATHS`, on top
of the C++ core and pod internals that `ReactNativeEnrichedMarkdown.podspec`
sets. `ios/vendor` and `ios/generated` are deliberately left out: sweeping
`vendor` in pulls the RaTeX xcframework module maps into scope and clang rejects
the duplicate `RaTeXFFI` module definitions.

`scripts/test-ios.sh` counts the `- (void)test` prototypes here and fails if
fewer tests than that actually ran, so a suite dropping out of the run cannot
leave the lane green.

`EnrichedMarkdownExampleTests.m` in the app-side target dir is a harness
placeholder that keeps the bundle non-empty; it can stay or be removed once real
suites land here. `SwiftLinker.swift` next to it is an empty presence-only file:
the host app and the pod contain Swift, so the test bundle must link the Swift
runtime (otherwise CI's pinned Xcode fails with
`Undefined symbol __swift_FORCE_LOAD_$_swiftCompatibility56`). Keep it.
