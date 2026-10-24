# Display benchmark (React Native)

Microbenchmarks of how long `react-native-enriched-markdown` takes on Android to display
an already-parsed document on the first screen, split into phases.

It mirrors `packages/enriched-markdown-android/display-benchmark`: same fixtures, same
four benchmarks, same measured regions.

The module is part of the example app's Gradle build, the only build that contains
`:react-native-enriched-markdown`. The app does not depend on it, and it is not part of
the published package.

## What is measured

Each document is parsed once, before measuring. Every iteration then runs on the main
thread through `measureRepeatedOnMainThread`.

| Benchmark | Measured region |
|---|---|
| `full` | Build the style and the view from the parsed document, attach it, measure, lay out, record one draw |
| `render` | `Renderer.renderDocument` alone: document to spannable |
| `layout` | `applyStyledText`, measure and layout of a rendered spannable |
| `draw` | One recorded draw of a laid-out view |

`full` is the headline number. The phases leave view and style construction out of the
measurement, so they do not add up to `full`, and a phase slower than `full` means the
benchmark is broken.

The whole document is rendered into a single text view, as with the `commonmark` flavor.

Not measured: parsing, the background thread the real views render on, RenderThread and
GPU work, and removing the view between iterations.

`full` also saves a screenshot of each document next to the results and fails if nothing
was drawn.

### Differences from the enriched-markdown-android benchmark

- **Style.** React Native builds its style from the `markdownStyle` map sent by JS.
  `default_style.json` is that map for an app that sets no style (see
  [Default style](#default-style)).
- **Native parser.** In an app, autolinking builds the library's native code. This module
  has no app, so `CMakeLists.txt` builds the parser itself, without syntax highlighting.
  The fixtures contain no highlighted languages, so this does not change the results.
- **R8.** The test APK is minified with R8, as in the other benchmark. The example app,
  like the React Native template, ships without R8.

### Pitfalls

Both of these make the benchmark report wrong numbers without failing:

- `draw` must invalidate the view tree before each recording. Otherwise it re-uses the
  previous display list and measures almost nothing.
- `layout` must render a new spannable every iteration. The library passes the spannable
  to the text view without copying it, so reusing one collects listeners from every
  previous view and slows down each iteration.

## Fixtures

The documents are read from
`packages/enriched-markdown-android/display-benchmark/src/androidTest/assets/`, so both
benchmarks use identical inputs. See that module's README for what they contain.

## Default style

`src/androidTest/assets/default_style.json` is generated from the library's
`normalizeMarkdownStyle`. Regenerate it after changing the default style (needs Node
22.18+ and `yarn install`):

```sh
node apps/react-native-example/android/display-benchmark/tools/generate-default-style.mjs
```

## Running

Use a physical device; emulator numbers are not meaningful. Keep it plugged in and
unlocked, with the screen on and other apps closed.

From `apps/react-native-example/android`, after `yarn install`:

```sh
ANDROID_SERIAL=<serial> ./gradlew :display-benchmark:connectedReleaseAndroidTest \
  -PreactNativeArchitectures=arm64-v8a
```

Run only some documents:

```sh
... -Pandroid.testInstrumentationRunnerArguments.mdbench.documents=complex_large
```

Check correctness without measuring (writes the screenshots but no results):

```sh
... -Pandroid.testInstrumentationRunnerArguments.androidx.benchmark.dryRunMode.enable=true
```

### Results

Results are written to
`display-benchmark/build/outputs/connected_android_test_additional_output/releaseAndroidTest/connected/<device>/`,
in `com.swmansion.enriched.markdown.benchmark.test-benchmarkData.json`, next to the
screenshots and Perfetto traces. Compare `metrics.timeNs.median`.

To measure a change, run the benchmark several times before and after it on the same
device and compare the medians. `layout` is the noisiest: garbage from its unmeasured
setup can be collected during the measurement.

The number of spans rendered for each document is logged by `full`:

```sh
adb -s <serial> logcat -s DisplayBenchmark
```

## Not in CI

Microbenchmarks need a dedicated physical device to give stable numbers, so this module
is not run in CI.
