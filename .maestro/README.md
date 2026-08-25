# Maestro E2E Tests

End-to-end UI tests for the example app, exercising both the display component (`EnrichedMarkdownText`) and the editor (`EnrichedMarkdownTextInput`). Tests run on iOS simulators and Android emulators via [Maestro](https://maestro.mobile.dev/).

```
.maestro/
├── config.yaml              ← all tests
├── config-smoke.yaml        ← smoke tag only
├── config-advanced.yaml     ← advanced tag only
├── enrichedMarkdownText/    ← display component suite
│   ├── flows/{basic,advanced}/{block,inline}_elements/
│   ├── subflows/            ← suite-local helpers
│   └── screenshots/         ← golden images, per platform
├── enrichedMarkdownInput/   ← editor suite (same shape)
├── androidExample/        ← native Android example app (CommonMark flows)
├── iosExample/            ← native iOS example app (CommonMark flows)
├── subflows/                ← cross-suite helpers
└── scripts/                 ← runner shell scripts + setup
```

## Yarn scripts

All scripts wrap `.maestro/scripts/run-tests.sh` (single platform) or `.maestro/scripts/run-all-tests.sh` (both platforms, sequentially). Use the yarn scripts as the entry point.

| Script | What it does |
|---|---|
| `yarn test:e2e:mobile` | Full suite on **iOS then Android**. |
| `yarn test:e2e:ios` | Full suite on iOS only. |
| `yarn test:e2e:android` | Full suite on Android only. |
| `yarn test:e2e:smoke:mobile` | `smoke`-tagged tests on both platforms. Fastest sanity check. |
| `yarn test:e2e:smoke:ios` | `smoke`-tagged tests on iOS. |
| `yarn test:e2e:smoke:android` | `smoke`-tagged tests on Android. |
| `yarn test:e2e:advanced:mobile` | `advanced`-tagged tests on both platforms. Default "did I break anything" pass. |
| `yarn test:e2e:advanced:ios` | `advanced`-tagged tests on iOS. |
| `yarn test:e2e:advanced:android` | `advanced`-tagged tests on Android. |
| `yarn test:e2e:mobile:update-screenshots` | Refresh golden screenshots for both platforms instead of asserting. |
| `yarn test:e2e:ios:update-screenshots` | Refresh golden screenshots for iOS only. |
| `yarn test:e2e:android:update-screenshots` | Refresh golden screenshots for Android only. |
| `yarn test:e2e:ios-native` | CommonMark E2E tests on the native iOS example app. |
| `yarn test:e2e:ios-native:smoke` | Smoke CommonMark tests on the native iOS example app. |
| `yarn test:e2e:ios-native:update-screenshots` | Refresh golden screenshots for the native iOS example app. |
| `yarn test:e2e:android-native` | CommonMark E2E tests on the native Android example app. |
| `yarn test:e2e:android-native:smoke` | Smoke CommonMark tests on the native Android example app. |
| `yarn test:e2e:android-native:update-screenshots` | Refresh golden screenshots for the native Android example app. |

### When to use which

- Iterating on a single change → `yarn test:e2e:smoke:ios` (or `:android`).
- Pre-PR regression check → `yarn test:e2e:advanced:mobile`.
- Updating goldens after an intentional visual change → `yarn test:e2e:mobile:update-screenshots`. Commit the new images alongside the code change.

## Direct script options

For anything not covered by the yarn scripts (custom tag filters, specific flows, forced rebuild), run `.maestro/scripts/run-tests.sh` directly.

| Option | Description |
|---|---|
| `--platform <ios\|android>` | **Required.** Target platform. |
| `--config <file>` | Path to a Maestro config (`.maestro/config*.yaml`). Drives flow discovery and tag filtering. |
| `--include-tags <a,b,c>` | Comma-separated tags to include. Passed through to Maestro. |
| `--exclude-tags <a,b,c>` | Comma-separated tags to exclude. Merged with the automatic platform exclusion (`ios-only` / `android-only`). |
| `--update-screenshots` | Refresh golden screenshots instead of asserting against them. |
| `--rebuild` | Force a rebuild + reinstall even if the example app is already on the device. |
| `[flows...]` | Specific flow files or directories to run. Defaults to all suites when omitted. |

### Examples

```bash
# Just the block-level tests on iOS
.maestro/scripts/run-tests.sh --platform ios --include-tags block

# Smoke pass excluding image-heavy flows
.maestro/scripts/run-tests.sh --platform android --config .maestro/config-smoke.yaml --exclude-tags image

# Run a single flow file
.maestro/scripts/run-tests.sh --platform ios .maestro/enrichedMarkdownText/flows/basic/block_elements/paragraph_test.yaml

# Force a clean rebuild before running
.maestro/scripts/run-tests.sh --platform ios --rebuild
```

## Tags

Every flow declares one or more `tags:` in its frontmatter. Use them with `--include-tags` (above) or in a config's `includeTags:` list to slice the suite.

### Workflow tags

| Tag | Meaning |
|---|---|
| `smoke` | Minimal smoke pass — fast, runs against `config-smoke.yaml`. Use for quick sanity. |
| `advanced` | Full coverage — exhaustive matrices of element combinations. Runs against `config-advanced.yaml`. The default for thorough regression checks. |

### Component tags

| Tag | Meaning |
|---|---|
| `text` | Flows under `enrichedMarkdownText/` — display component. |
| `input` | Flows under `enrichedMarkdownInput/` — editor component. |

### Category tags

| Tag | Meaning |
|---|---|
| `block` | Any block-level element test (paragraphs, headings, lists, blockquotes, tables, code blocks, etc.). |
| `inline` | Any inline-element test (bold, italic, links, inline code, etc.). |

### Block-element tags

Apply to tests that exercise the corresponding element. Many flows wear multiple tags (e.g. a paragraph-with-image combo carries both `paragraph` and `image`).

| Tag | Element |
|---|---|
| `paragraph` | Plain paragraphs and combos. |
| `header` | Headings H1–H6 (Markdown `#`, `##`, …). |
| `blockquote` | Blockquotes, including nested. |
| `list` | Ordered and unordered lists. |
| `task_list` | GFM task lists (checkboxes). Requires `flavor="github"`. |
| `code_block` | Fenced code blocks. |
| `table` | GFM tables. Requires `flavor="github"`. |
| `image` | Block and inline images. |
| `math` | LaTeX math blocks and inline (`$…$`, `$$…$$`). Requires `latexMath` flag. |
| `thematic_break` | Horizontal rules (`---`). |

### Inline-element tags

| Tag | Element |
|---|---|
| `bold` | `**bold**` |
| `italic` | `*italic*` |
| `underline` | `__underline__` (requires `underline` md4c flag). |
| `strikethrough` | `~~strikethrough~~` |
| `link` | `[text](url)` |
| `inline_code` | `` `code` `` spans (distinct from `code_block`). |
| `spoiler` | `\|\|spoiler\|\|` |
| `highlight` | `==highlight==` (requires `highlight` md4c flag). |

### Platform exclusion tags

These are automatically applied by `run-tests.sh` based on `--platform`; flows tagged here are skipped on the other platform. You typically don't pass these explicitly.

| Tag | Meaning |
|---|---|
| `ios-only` | Auto-excluded when running on Android. |
| `android-only` | Auto-excluded when running on iOS. |

## Screenshot baselines

Stored under each suite's `screenshots/<platform>/` directory and asserted with `thresholdPercentage: 100` (pixel-exact). Cropping is done via element ID — see `subflows/capture_or_assert_screenshot.yaml`.

When a visual change is intentional, refresh the baselines:

```bash
yarn test:e2e:mobile:update-screenshots
```

Then commit the regenerated PNGs alongside the code.

## Requirements

- **Maestro CLI ≥ 2.5.0** — `run-tests.sh` enforces this.
- **iOS**: Xcode + a simulator. The runner auto-selects one via `setup-ios-simulator.sh`.
- **Android**: Android Studio + an AVD. The runner auto-selects one via `setup-android-emulator.sh`.
- The example app's bundle id is `swmansion.enriched.markdown.example` — built and installed automatically on first run, or via `--rebuild`.

## Adding a new flow

1. Drop the `.yaml` under the matching suite + category — e.g. `enrichedMarkdownText/flows/advanced/block_elements/`.
2. Add the right `tags:` at the top (`block` + element tag + `text` for the suite, plus `advanced` or `smoke`). Keep the tag vocabulary in this README in sync.
3. If the flow does screenshot assertions, generate the baseline by running once with `--update-screenshots` and committing the PNG.

## Troubleshooting

- **"maestro CLI not found"** → install via Maestro's docs.
- **"maestro <ver> is too old"** → upgrade past 2.5.0.
- **App not installed / stale build** → pass `--rebuild` to force a clean build, or delete the app from the simulator manually.
- **Flow can't find an asset** → the runner injects `.maestro/assets/` automatically; make sure your asset path is relative to that.
