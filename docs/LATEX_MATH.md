# LaTeX Math

LaTeX math rendering is supported for both block and inline equations:

- **Block math (`$$...$$`)**: Rendered as a standalone display element. Requires `flavor="github"`.
- **Inline math (`$...$`)**: Rendered within the text flow. Works with both `flavor="commonmark"` and `flavor="github"`.

## Usage

```tsx
<EnrichedMarkdownText
  flavor="github"
  markdown={`
The quadratic formula:

$$x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}$$

Einstein's mass-energy equivalence $E = mc^2$ is one of the most famous equations.
  `}
  markdownStyle={{
    math: {
      fontSize: 20,
      color: '#1F2937',
      backgroundColor: '#F3F4F6',
      padding: 12,
      textAlign: 'center',
    },
    inlineMath: {
      color: '#1F2937',
    },
  }}
/>
```

Block math equations are rendered as standalone display elements with spacing and an optional background. Inline math inherits the surrounding block's typography.

> [!IMPORTANT]
> LaTeX commands use backslashes (e.g. `\frac`, `\alpha`). In regular JS strings and template literals, backslashes are escape characters. Use `String.raw` or double backslashes (`\\frac`) to preserve them. Block math (`$$...$$`) must be on its own line to render as a display element.

## Web

On web the library renders LaTeX via [KaTeX](https://katex.org/) in **MathML output mode**. Browsers render MathML natively — no CSS or font files are required.

### Installation

Install the optional peer dependency:

```sh
npm install katex
# or
yarn add katex
```

KaTeX is loaded lazily the first time a LaTeX node is encountered, so it has no impact on pages that do not render math. No stylesheet or `<link>` tag is needed.

> [!NOTE]
> MathML is supported natively in Chrome 109+, Firefox, and Safari. Older browsers will display the raw LaTeX source as a text fallback.

### Disabling on web

Pass `latexMath: false` in `md4cFlags` to skip parsing and treat `$` as plain text:

```tsx
<EnrichedMarkdownText markdown="Price is $5" md4cFlags={{ latexMath: false }} />
```

This also prevents KaTeX from being loaded at runtime.

## Disabling LaTeX Math (reducing bundle size)

LaTeX math rendering relies on **RaTeX** — a native, KaTeX-compatible math engine — on both iOS and Android. It is included by default but can be excluded to reduce your app's binary size (~3–5 MB on iOS, varies on Android).

### 1. Disable at the parser level (JS)

Set `latexMath: false` in `md4cFlags` so the parser treats `$` as plain text:

```tsx
<EnrichedMarkdownText markdown="Price is $5" md4cFlags={{ latexMath: false }} />
```

This alone prevents math rendering without any native changes. The steps below go further by removing the native math libraries from your binary entirely.

### 2. Remove the native dependency

Set `enableMath` to `false` in the `enriched-markdown` block of your app's `package.json`:

```json
{
  "enriched-markdown": {
    "enableMath": false
  }
}
```

This is the single source of truth for both platforms: `postinstall` skips the install-time RaTeX
download, and the native build reads the same block directly to exclude **RaTeX** from the binary — no
Podfile or `gradle.properties` edit needed. Re-run `pod install` (iOS) / rebuild (Android) after
changing it. See [Skipping the download](./NATIVE_ASSETS.md#skipping-the-download-opt-out).

> [!NOTE]
> **Deprecated:** the `ENV['ENRICHED_MARKDOWN_ENABLE_MATH']` Podfile variable and the
> `enrichedMarkdown.enableMath` gradle property still work as a fallback but are deprecated and print a
> warning; they are ignored when the `package.json` block sets `enableMath`.

> [!NOTE]
> When math is **enabled** (the default), no special Podfile configuration is required.
> RaTeX ships as a prebuilt static XCFramework vendored into the pod, so it links under
> CocoaPods default static linkage — you do **not** need `use_frameworks!`. (Earlier
> versions required `use_frameworks! :linkage => :dynamic` to resolve RaTeX as a Swift
> Package; that is no longer the case.)

> [!NOTE]
> The RaTeX XCFramework is **not** bundled in the npm tarball — it is downloaded at install time by
> a `postinstall` script (see [Native assets](./NATIVE_ASSETS.md)). If `ios/vendor/RaTeX.xcframework`
> is missing (offline install, `--ignore-scripts`, pnpm, or a `package.json` opt-out) and math is only
> on by default, `pod install` auto-disables math and prints a warning instead of failing. If you
> **explicitly** set `"enableMath": true`, a missing framework is a hard error instead. Either way, run
> `node node_modules/react-native-enriched-markdown/postinstall.mjs` and re-run `pod install` to restore it.

> [!IMPORTANT]
> **Upgrading from a version that used `use_frameworks! :linkage => :dynamic` for math?**
> The pod changed from a dynamic framework to a static library. After `pod install`,
> do a one-time clean build (Xcode: Product > Clean Build Folder, or delete the app's
> DerivedData) — a stale build folder otherwise fails with
> `ReactNativeEnrichedMarkdown.framework/Modules/module.modulemap not found`. Fresh
> installs are unaffected.

> [!NOTE]
> **macOS**: LaTeX math is not yet enabled on macOS and remains off in the macOS example
> app. The previous blocker (`use_frameworks!` was required for the RaTeX Swift Package)
> no longer applies now that RaTeX is a vendored XCFramework with a macOS slice, so macOS
> support is a possible future follow-up.

### 3. Expo

The `package.json` block above works with Expo too — `node_modules` (and the resolved config) survive
`npx expo prebuild`, so no config plugin is needed. Set `"enriched-markdown": { "enableMath": false }` in
your app's `package.json` and rebuild.

> [!NOTE]
> Because `enableMath` is a compile/link-time decision, it only applies in builds you compile yourself
> (a custom dev client or `expo prebuild`). It **cannot** be changed in **Expo Go**, which ships a fixed
> prebuilt binary. A dedicated config plugin was removed in favor of the `package.json` block — see
> [Breaking changes](./BREAKING_CHANGES.md).
