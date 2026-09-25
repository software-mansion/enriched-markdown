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

`EnrichedMarkdownExample.xcodeproj` is objectVersion 54 and lists sources
explicitly, so a new `.mm`/`.m` here must be added to the
`EnrichedMarkdownExampleTests` target's Compile Sources phase. In Xcode: open
the workspace, drag the file into the `EnrichedMarkdownExampleTests` group with
the target checked. By hand in `project.pbxproj`, add the file as a
`PBXFileReference` (with `sourceTree = SOURCE_ROOT` and a path such as
`../../../packages/react-native-enriched-markdown/__tests__/ios/<File>.mm`), a
matching `PBXBuildFile`, and reference it from the target's
`00E356EA...` Sources build phase.

Test files import the code under test by relative path, e.g.
`#import "../../ios/attachments/ENRMLinkPillTextStorage.h"`. Header search paths
for the C++ core and pod internals are set on the test target's build
configuration, mirroring `ReactNativeEnrichedMarkdown.podspec`.

`EnrichedMarkdownExampleTests.m` in the app-side target dir is a harness
placeholder that keeps the bundle non-empty; it can stay or be removed once real
suites land here. `SwiftLinker.swift` next to it is an empty presence-only file:
the host app and the pod contain Swift, so the test bundle must link the Swift
runtime (otherwise CI's pinned Xcode fails with
`Undefined symbol __swift_FORCE_LOAD_$_swiftCompatibility56`). Keep it.
