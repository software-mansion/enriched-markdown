# Display benchmark

Microbenchmarks of the time to display an **already-parsed** document on the first
screen, plus a phase split that says which part of that time is spent where.

This module is measurement scaffolding. It depends on `project(":ui")` directly, so an
optimisation can be measured without publishing anything, and it is never published
itself: the root `subprojects` block applies the publish script only to `parser`, `ui`
and `compose`, and `nmcpAggregation` does not list it. ktlint does apply here, as it
does to every module.

## What is measured

The document is parsed once, before measuring, with
`Md4cFlags(permissiveAutolinks = false)`. Each iteration then runs **on the main
thread**, through `benchmarkRule.measureRepeatedOnMainThread`.

| Benchmark | Measured region |
|---|---|
| `full` | The end-to-end path: build the view from the parsed AST, attach it, measure, lay out, record one draw |
| `render` | `Renderer.renderDocument(ast)` alone — AST to a spannable buffer |
| `layout` | `setText` + `measure` + `layout` on a pre-rendered spannable |
| `draw` | One recorded draw of a view that is already laid out |

`full` is the headline number; keep its measured region unchanged so results stay
comparable across runs. `render`, `layout` and `draw` share the same fixture and the same
parsed AST.

The phases do **not** sum to `full`, and are not meant to: `full` constructs the text view
and `StyleConfig.default(context)` inside its measured region, while each phase hoists that
setup out so it measures the phase alone. Expect `SUM/full` between roughly 0.5 and 0.9,
lowest on small documents where view construction is the largest share. A phase exceeding
`full` is a bug in the benchmark, not a finding.

The view under test is a markdown `TextView` inside a `ScrollView`, built from the parsed
AST synchronously:

```kotlin
val textView = EnrichedMarkdownInternalText(context).apply { setIsSelectable(false) }
val renderer = Renderer().apply { configure(StyleConfig.default(context), context) }
textView.text = renderer.renderDocument(document)
```

`EnrichedMarkdown` is the container that owns `markdownStyle`; `EnrichedMarkdownInternalText`
is the `TextView` inside it. The benchmark uses the text view directly and builds the style
with `StyleConfig.default(context)`, which is exactly the value `EnrichedMarkdown.markdownStyle`
is initialised to, so the measured work is what the container would do.

### Deliberately excluded

- **Parsing.** It happens once, outside the measured region.
- **RenderThread and GPU work.** The draw is recorded into a `RenderNode`, which is the
  UI-thread half of a real frame. What the GPU then does with that display list is not
  measured. This is why the module needs `minSdk 29`.
- **Removing the view** between iterations, which runs inside
  `runWithMeasurementDisabled`.
- **Per-iteration setup in the phase benchmarks.** Constructing
  `EnrichedMarkdownInternalText` is not free — its `init` runs `setupAsMarkdownTextView()`,
  which calls `setTextIsSelectable(true)` (creating an `Editor`, a `setText` and a movement
  method), and `setIsSelectable(false)` then does it again; `StyleConfig.default(context)`
  builds the whole style tree. `full` keeps all of that inside the measured region. The
  phase benchmarks hoist it out, so each phase measures the phase.

### Two contracts that must not be broken

Both of these were live bugs once. Each produced a plausible-looking number rather than an
obvious failure, so neither is caught by the tests passing.

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
  growing set. `layout` then drifts upward until it exceeds `full` on documents whose own
  span count is too small to hide the accumulation. Note this is an artifact of the
  no-copy path: against a library version that copies on `setText`, the shared buffer
  would not accumulate anything.

`full` also saves the first screen of each document as a PNG next to the results and
asserts it is not blank, which catches a renderer that silently draws nothing.

## Fixtures

Six generated documents live in `src/androidTest/assets/`. Numbers are only comparable
against identical inputs, so do not edit them by hand. They use plain CommonMark only:
headings, paragraphs, emphasis, code spans, fenced and indented code blocks, block quotes,
nested lists, thematic breaks, links and hard breaks. No tables, images, strikethrough,
autolinks, task lists or HTML.

`simple_*` is headings and plain paragraphs; `complex_*` mixes every supported construct.
Both size ladders share byte targets (~2 KB / ~20 KB / ~100 KB), so a cost difference
between them comes from the markup rather than from the amount of text.

`tools/generate-documents.mjs` generates them. It uses a fixed-seed PRNG, so it reproduces
the committed files byte for byte. It writes to `<parent-of-tools>/fixtures`, i.e.
`display-benchmark/fixtures/`, so regenerating means copying the result over the assets:

```sh
node display-benchmark/tools/generate-documents.mjs
cp display-benchmark/fixtures/{simple,complex}_{small,medium,large}.md \
   display-benchmark/src/androidTest/assets/
```

It also emits `feature_showcase.md`, a one-of-each visual parity document that this
module does not benchmark and does not carry.

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

```sh
ANDROID_SERIAL=<serial> ./gradlew :display-benchmark:connectedReleaseAndroidTest
```

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
`build/outputs/connected_android_test_additional_output/releaseAndroidTest/connected/<device>/`.
The results file is named after the test package, not plainly `benchmarkData.json`:

```
com.swmansion.enriched.markdown.benchmark.test-benchmarkData.json
DisplayBenchmark_<document>.png                     # one per document, from `full`
DisplayBenchmark_<benchmark>_<document>__*.perfetto-trace
DisplayBenchmark_<benchmark>_<document>_-methodTracing-*.trace
```

Each entry in that JSON carries `metrics.timeNs` with `minimum`, `median` and `maximum`;
the median is the number to quote. Compare like for like — same device, same thermal
state. The `.perfetto-trace` and method-tracing files come from the benchmark library's
own profiling and are worth opening when a phase is slower than expected.

`full` also logs how many spans the renderer produced for each document, counted on the
rendered buffer before a view holds it, and outside the measured region. It goes to
logcat rather than the output directory:

```sh
adb -s <serial> logcat -s DisplayBenchmark
```

A dry run writes the PNGs and a per-test message `.txt`, but **no** results JSON.

The results JSON also records whether a run hit thermal throttling. The module sets
`androidx.benchmark.measureRepeatedOnMainThread.throwOnDeadline=false` because the
benchmark library's ~90 s cool-down otherwise counts against the 10 s main-thread
deadline and fails the test.


## Not in CI

This module is deliberately absent from `.github/workflows/ci.yml`. Microbenchmarks need
a physical device with locked clocks to produce stable numbers; a shared CI runner would
only produce noise.
