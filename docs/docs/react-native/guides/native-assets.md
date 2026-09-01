---
sidebar_label: Native assets
sidebar_position: 3
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Native assets

Two kinds of native assets matter when you ship Enriched Markdown: the **fonts
and images you bundle** into your app and reference from Markdown, and the
**large prebuilt assets the library itself downloads** at install time for LaTeX
math and code highlighting. This guide covers both - how to reference your own
assets, and how the library's assets are fetched and how to opt out of them to
shrink your binary.

## Custom fonts

Font resolution goes through React Native's font manager (`RCTFont` on iOS,
`ReactFontManager` on Android), so any font bundled the normal React Native way
is available to `markdownStyle`. There are two steps: bundle the font, then
reference its family name.

### Bundle the font

<Tabs groupId="project-type">
  <TabItem value="expo" label="Expo">

Use the [`expo-font`](https://docs.expo.dev/develop/user-interface/fonts/)
config plugin to embed the fonts into the native build. Embedding (rather than
the runtime `useFonts` hook) makes the fonts available immediately on startup,
which is what the native renderer needs:

```bash
npx expo install expo-font
```

```json
// app.json
{
  "expo": {
    "plugins": [
      [
        "expo-font",
        {
          "fonts": [
            "./assets/fonts/Montserrat-Regular.ttf",
            "./assets/fonts/Montserrat-Bold.ttf"
          ]
        }
      ]
    ]
  }
}
```

Then rebuild the native projects:

```bash
npx expo prebuild --clean
npx expo run:ios # or: npx expo run:android
```

The plugin also accepts per-weight `fontDefinitions` and platform-specific
lists - see the [Expo fonts guide](https://docs.expo.dev/develop/user-interface/fonts/).

  </TabItem>
  <TabItem value="bare" label="Bare React Native">

Point `react-native.config.js` at your fonts folder:

```js
// react-native.config.js
module.exports = {
  assets: ['./assets/fonts'],
};
```

Copy the fonts into the native projects with
[`react-native-asset`](https://github.com/unimonkiez/react-native-asset), then
rebuild:

```bash
npx react-native-asset
```

On iOS this registers the fonts in `Info.plist` (`UIAppFonts`); on Android it
copies them into `assets/fonts`. Rebuild the app afterwards.

  </TabItem>
</Tabs>

### Reference the font

Set `fontFamily` anywhere `markdownStyle` accepts typography - it cascades from a
block to its inline children. Use the same family name you would pass to a React
Native `<Text>` (the font's PostScript / family name, e.g. `Montserrat-Regular`):

```tsx
<EnrichedMarkdownText
  markdown={'# Heading\n\nBody copy set in a **custom** font.'}
  markdownStyle={{
    paragraph: { fontFamily: 'Montserrat-Regular' },
    h1: { fontFamily: 'Montserrat-Bold' },
  }}
/>
```

The same `fontFamily` works in `EnrichedMarkdownTextInput`'s style prop. For
which style keys accept `fontFamily` and how it interacts with bold and italic,
see [Style properties](/react-native/api-reference/style-properties#custom-font-family-for-inline-styles).

:::note
Single-file custom fonts (one face, with no bundled `_bold` / `_italic` variant
files) are handled gracefully: the library loads the font at its regular weight
and synthesizes bold and italic on top, so `**bold**` and `*italic*` still render
in your font instead of falling back to the system face. If you ship separate
weight files and want them used as-is, set `fontWeight` / `fontStyle` to
`'normal'` on that style (see the Style properties link above).
:::

## Bundled images

Markdown image URLs are plain strings, so a `require()`d image must be resolved
to a URI before it goes into the Markdown:

```tsx
import { Image } from 'react-native';

const logoUri = Image.resolveAssetSource(require('./assets/logo.png')).uri;
const markdown = `![Logo](${logoUri})`;
```

This works in development (a Metro dev-server URL) and in release builds (a
drawable resource on Android, a bundle `file://` URL on iOS). For the full list
of supported image sources per platform - and how images are cached - see
[Image caching](/react-native/guides/image-caching#supported-image-sources).

## Install-time native downloads

Two parts of the library's native layer are large prebuilt assets: the
tree-sitter runtime and grammar sources for
[code-block highlighting](/rich-text-formatting/code-highlighting) and the RaTeX
static XCFramework for [iOS LaTeX math](/rich-text-formatting/latex-math).
Shipping them inside the npm tarball would push every install past 200 MB, even
for apps that use neither feature.

Instead they are **downloaded once at install time** by a `postinstall` script,
keeping the published package small. Each download is verified by sha256 and is
idempotent - a `.stamp` fingerprint in each vendor directory makes repeated
installs a no-op.

### What gets downloaded

| Asset | Source | Used by |
|---|---|---|
| tree-sitter runtime | GitHub release tarball | code highlighting (iOS + Android) |
| grammar sources (`parser.c` / `scanner.c` / `highlights.scm`) | npm registry | code highlighting (iOS + Android) |
| RaTeX XCFramework + fonts | GitHub release | LaTeX math (iOS only) |

Files land under `node_modules/react-native-enriched-markdown/` (`cpp/highlight/vendor/`
for grammars and runtime, `ios/vendor/` for RaTeX). Because this runs during
`npm install` / `yarn add`, the assets are in place before `pod install` or the
Android build reads them.

### Requirements

- **Network access at install time** to `registry.npmjs.org` and `github.com`.
- `tar` (present on macOS, Linux, and Windows 10+). RaTeX also needs `unzip`,
  which is absent on stock Windows - but RaTeX is iOS-only, so this only affects
  Windows dev machines and is non-fatal.

The postinstall step **never fails the install**: if a download does not complete
it prints a warning and exits successfully. What the native build does with a
missing asset depends on whether you explicitly enabled the feature:

- **On by default** (no `enriched-markdown` entry): the build treats the feature
  as disabled - code highlighting compiles a no-op stub, iOS math is skipped with
  a CocoaPods warning - so the build stays green.
- **Explicitly enabled** (`"enableMath": true` / `"enableCodeHighlight": true`):
  the build **fails with an actionable error** telling you to re-run postinstall.

### Recovering a failed or skipped download

If a download didn't complete (offline, behind a firewall, or with scripts
disabled), reinstall the package to re-fetch the assets:

```bash
npm rebuild react-native-enriched-markdown
```

If your package manager blocks or skips that (pnpm, Yarn PnP, `--ignore-scripts`),
run the vendor script directly from your project root:

```bash
node node_modules/react-native-enriched-markdown/postinstall.mjs
```

Then re-run `pod install` (iOS) or rebuild (Android).

:::note
**Package managers.** npm and Yarn (node-modules linker) work out of the box.
**pnpm** blocks dependency lifecycle scripts by default - allow this package to
run its `postinstall` (e.g. add it to `onlyBuiltDependencies`). **Yarn PnP** is
not supported: its read-only archives can't receive the vendored assets, so use
the `node-modules` linker (the norm for React Native anyway). With
**`--ignore-scripts`**, run the recovery command above after installing.
:::

## Reducing binary size (opt out) {#reducing-binary-size}

If you don't use a feature, opt out in **your app's `package.json`** so the
postinstall never downloads its assets and the native build never links them. Add
an `enriched-markdown` block (both fields default to `true`):

```json
{
  "enriched-markdown": {
    "enableCodeHighlight": false,
    "enableMath": false
  }
}
```

`enableCodeHighlight: false` skips the tree-sitter runtime and grammar download
(iOS and Android). `enableMath: false` skips the RaTeX download (iOS only;
Android math uses a Maven dependency and is unaffected). The native build reads
the same block directly, so a `package.json` opt-out also disables the feature at
build time - no Podfile or `gradle.properties` edit needed.

:::important
**Applying a change on iOS.** The podspec reads `package.json` at `pod install`
time, so run `pod install` after editing the block. When you disable a feature
that was already compiled in, also do a clean build (`Product > Clean Build
Folder`, or delete the app's DerivedData): Xcode's incremental build does not
reliably rebuild the pod's static library when only its source list changes.
Android reconfigures on every build and needs neither step.
:::

**Which `package.json`?** The download opt-out is read from wherever the install
runs (in a monorepo, the workspace root with the shared `node_modules`), so it is
global. The build flag is read from the **app's** `package.json` (the one beside
`ios/` and `android/`), so each app in a monorepo enables or disables features
independently.

You can also narrow or disable a feature purely at build time (the assets stay
downloaded but are never compiled) - for example trimming the code-highlighting
language set. See [Code-block highlighting](/rich-text-formatting/code-highlighting)
and [LaTeX math](/rich-text-formatting/latex-math) for the per-feature options.

Expo works with the same block - `node_modules` survives `npx expo prebuild`, so
no config plugin is needed (a dedicated plugin was removed; see
[Breaking changes](/misc/breaking-changes)).

:::caution
Because it is a compile/link-time decision, it cannot be changed in Expo Go.
:::
