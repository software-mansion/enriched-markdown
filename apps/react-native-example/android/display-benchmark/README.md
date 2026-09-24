# Display benchmark (React Native)

Microbenchmarks of the time `react-native-enriched-markdown` takes to display an
**already-parsed** document on the first screen on Android, plus a phase split that says
which part of that time is spent where.

It is the React Native counterpart of
`packages/enriched-markdown-android/display-benchmark`: same fixtures, same four
benchmarks, same measured regions, so the two libraries can be compared on one device.

This module is measurement scaffolding. It lives in the example app's Gradle build
because that is the only build containing `:react-native-enriched-markdown`, and it
depends on that project directly, so an optimisation can be measured without publishing
anything. The app does not depend on it, and nothing here is shipped: it is outside the
library's package. ktlint applies to it as it does to the library (`yarn lint-kotlin`).

## What is measured

The document is parsed once, before measuring, with the flags JS sends for the default
`commonmark` flavor, except `permissiveAutolinks = false` (as in the other benchmark).
Each iteration then runs **on the main thread**, through
`benchmarkRule.measureRepeatedOnMainThread`.

| Benchmark | Measured region |
|---|---|
| `full` | The end-to-end path: build the style and the view from the parsed AST, attach it, measure, lay out, record one draw |
| `render` | `Renderer.renderDocument(ast)` alone — AST to a spannable buffer |
| `layout` | `applyStyledText` + `measure` + `layout` on a pre-rendered spannable |
| `draw` | One recorded draw of a view that is already laid out |

`full` is the headline number; keep its measured region unchanged so results stay
comparable across runs. `render`, `layout` and `draw` share the same fixture and the same
parsed AST.

The phases do **not** sum to `full`, and are not meant to: `full` constructs the text view
and the `StyleConfig` inside its measured region, while each phase hoists that setup out
so it measures the phase alone. A phase exceeding `full` is a bug in the benchmark, not a
finding.

The view under test is a markdown `TextView` inside a `ScrollView`, built from the parsed
AST synchronously, the way `SegmentViewCreators.createTextView` builds a text segment:

```kotlin
val style = StyleConfig(styleMap, context, allowFontScaling = true, maxFontSizeMultiplier = 0f)
val textView = EnrichedMarkdownInternalText(context).apply {
  setIsSelectable(false)
  setTextSize(TypedValue.COMPLEX_UNIT_PX, style.paragraphStyle.fontSize)
}
val renderer = Renderer().apply { configure(style, context) }
textView.applyStyledText(renderer.renderDocument(document))
```

The whole document goes into that one view, as the `commonmark` flavor renders it,
rather than being split into segments.

### How it differs from the enriched-markdown-android benchmark

- **The style comes from JS.** React Native builds `StyleConfig` from the `markdownStyle`
  map JS sends. `src/androidTest/assets/default_style.json` is that map for an app that
  sets no style, generated from the library's own `normalizeMarkdownStyle` (see
  [Default style](#default-style)). It is loaded into a `ReadableMap` once, outside the
  measurement, as props arrive before the view exists; turning it into a `StyleConfig`
  is inside `full`, as it is inside `setMarkdownStyle`.
- **There is no React Native host.** `StyleConfig` converts units through `PixelUtil`,
  so the harness initialises `DisplayMetricsHolder` itself.
- **The parser is built by this module.** The library's native code is compiled into the
  app by autolinking, together with Fabric codegen that needs ReactAndroid's prefab, and
  the library module builds no `.so` of its own. `CMakeLists.txt` builds the plain-JNI
  part — md4c, the parser and `jni-adapter.cpp` — under the library name the Kotlin side
  loads. Syntax highlighting is compiled out; the fixtures' only fenced language is
  `kotlin`, which has no grammar, so the app would not highlight them either.
- **No R8.** The example app ships its release build without minification
  (`enableProguardInReleaseBuilds = false`), so the test APK is not minified either.

### Deliberately excluded

- **Parsing.** It happens once, outside the measured region.
- **The background thread.** Both React Native views parse and render off the main
  thread and post the result; here every step runs synchronously on the main thread.
- **RenderThread and GPU work.** The draw is recorded into a `RenderNode`, which is the
  UI-thread half of a real frame. What the GPU then does with that display list is not
  measured. This is why the module needs `minSdk 29`.
- **Removing the view** between iterations, which runs inside
  `runWithMeasurementDisabled`.
- **Per-iteration setup in the phase benchmarks.** Constructing
  `EnrichedMarkdownInternalText` is not free — its `init` runs `setupAsMarkdownTextView()`,
  which calls `setTextIsSelectable(true)` (creating an `Editor`, a `setText` and a movement
  method), and `setIsSelectable(false)` then does it again. `full` keeps all of that inside
  the measured region. The phase benchmarks hoist it out, so each phase measures the phase.

### Two contracts that must not be broken

Both of these were live bugs once in the other benchmark. Each produced a plausible-looking
number rather than an obvious failure, so neither is caught by the tests passing.

- **`draw` invalidates the view tree before every recording.** A recorded draw only
  re-records children whose display list is dirty. With nothing dirtying the tree between
  iterations, `drawChild` skips `updateDisplayListIfDirty` and merely re-emits the previous
  display list by reference: the measured region collapses to about 1 us and zero
  allocations while recording nothing at all. `invalidateViewTree()` runs inside
  `runWithMeasurementDisabled`, so the invalidation itself stays unmeasured.
- **`layout` renders a fresh buffer every iteration.** The library hands the rendered
  buffer to the text view uncopied, so `setText` attaches the view's watchers to that very
  instance as spans. Sharing one buffer across iterations leaves the watchers of every
  discarded `TextView` on it — one more per iteration — and each later `setSpan` scans the
  growing set. `layout` then drifts upward until it exceeds `full`. Note this is an
  artifact of the no-copy path: against a library version that copies on `setText`, the
  shared buffer would not accumulate anything.

`full` also saves the first screen of each document as a PNG next to the results and
asserts it is not blank, which catches a renderer that silently draws nothing.

## Fixtures

The six documents are read in place from
`packages/enriched-markdown-android/display-benchmark/src/androidTest/assets/` (added to
this module's `androidTest` assets in `build.gradle`), so both benchmarks always measure
identical inputs. That module's README covers what they contain and how they are
generated; do not edit them by hand.

## Default style

`src/androidTest/assets/default_style.json` is generated, not written. Regenerate it after
changing the library's default style:

```sh
node apps/react-native-example/android/display-benchmark/tools/generate-default-style.mjs
```

It needs Node 22.18+ (it imports the library's TypeScript directly) and the workspace's
`node_modules`. It stubs `react-native` so `Platform` answers as Android and colors are
processed as `processColor` does there.

## Running

A **physical device**, not an emulator. Numbers from an emulator are meaningless here.
Lock clocks if the device supports it, keep it cool and plugged in, and close other apps.

Keep the screen **on and unlocked** for the whole run; the benchmark library refuses to
measure a locked device.

The harness drives its own `DisplayActivity` through `ActivityScenarioRule` rather than
measuring inside the benchmark library's `IsolationActivity`, so a run may mention
`ACTIVITY-MISSING`. On a physical device that marker is not expected; treat it appearing
there as a signal that the activity did not come to the foreground — not as something to
suppress by default.

From `apps/react-native-example/android`, after `yarn install` (the Gradle build needs
the workspace's `node_modules`):

```sh
ANDROID_SERIAL=<serial> ./gradlew :display-benchmark:connectedReleaseAndroidTest
```

The native parser is built for `arm64-v8a` unless `reactNativeArchitectures` says
otherwise; the example's `gradle.properties` lists every ABI, so pass
`-PreactNativeArchitectures=<abi>` to build only the device's.

Subset while iterating:

```sh
ANDROID_SERIAL=<serial> ./gradlew :display-benchmark:connectedReleaseAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.mdbench.documents=complex_large
```

Correctness-only check that skips measurement but still writes the screenshots:

```sh
ANDROID_SERIAL=<serial> ./gradlew :display-benchmark:connectedReleaseAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.androidx.benchmark.dryRunMode.enable=true
```

### Reading the output

Results land in
`display-benchmark/build/outputs/connected_android_test_additional_output/releaseAndroidTest/connected/<device>/`.
The results file is named after the test package, not plainly `benchmarkData.json`:

```
com.swmansion.enriched.markdown.benchmark.test-benchmarkData.json
DisplayBenchmark_<document>.png                     # one per document, from `full`
DisplayBenchmark_<benchmark>_<document>__*.perfetto-trace
DisplayBenchmark_<benchmark>_<document>_-methodTracing-*.trace
```

Each entry in that JSON carries `metrics.timeNs` with `minimum`, `median` and `maximum`;
the median is the number to quote. Compare like for like — same device, same thermal
state.

`full` also logs how many spans the renderer produced for each document, counted on the
rendered buffer before a view holds it, and outside the measured region:

```sh
adb -s <serial> logcat -s DisplayBenchmark
```

A dry run writes the PNGs and a per-test message `.txt`, but **no** results JSON.

The module sets `androidx.benchmark.measureRepeatedOnMainThread.throwOnDeadline=false`
because the benchmark library's ~90 s cool-down otherwise counts against the 10 s
main-thread deadline and fails the test.

## Not in CI

This module is deliberately absent from `.github/workflows/ci.yml`. Microbenchmarks need
a physical device with locked clocks to produce stable numbers; a shared CI runner would
only produce noise.
