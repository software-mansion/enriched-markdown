---
sidebar_label: Web support
sidebar_position: 1
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Web support

`EnrichedMarkdownText` runs on web as plain React and DOM primitives - the
renderer emits semantic HTML elements (`<p>`, `<h1>`-`<h6>`, `<blockquote>`,
`<ul>`, `<ol>`, `<table>`, etc.) styled with CSS. That keeps the output
accessible and lets browser features (text selection, the native context menu,
OS font scaling) work on their own.

Markdown parsing is handled by [md4c](https://github.com/mity/md4c) compiled to
WebAssembly. The WASM binary is inlined inside the JavaScript bundle
(`SINGLE_FILE=1`), so there is no separate `.wasm` asset to host or configure
and no build step is required by consumers.

:::note
Web support currently applies to `EnrichedMarkdownText` (the renderer).
`EnrichedMarkdownTextInput` (the editor) is native-only today, with **web
support coming soon** - see the [roadmap](/misc/roadmap). The
[Feature support](/introduction/supported-features) overview has the full
matrix.
:::

## Setup

### Install the library

<Tabs groupId="package-managers">
  <TabItem value="npm" label="npm">

```bash
npm install react-native-enriched-markdown
```

  </TabItem>
  <TabItem value="yarn" label="yarn">

```bash
yarn add react-native-enriched-markdown
```

  </TabItem>
  <TabItem value="pnpm" label="pnpm">

```bash
pnpm add react-native-enriched-markdown
```

  </TabItem>
</Tabs>

The same install-time caveats apply as on native - notably that pnpm skips the
package's `postinstall` unless you allow it. See
[Installation](/react-native/basics/installation#install-the-package).

### Set up a web target

The renderer is plain React. Your bundler only has to resolve the library's web
entry (`index.web.js`) instead of its native one, which means preferring `.web`
extensions. Follow the path that matches your project.

#### Expo

Expo ships web support through Metro. Add the web dependencies and start the web
server:

```bash
npx expo install react-dom react-native-web @expo/metro-runtime
npx expo start --web
```

Metro resolves platform-specific files automatically, so
`react-native-enriched-markdown` picks up its web build with no extra
configuration.

#### Bare React Native and other bundlers

Without Expo you need the web runtime packages and a handful of bundler rules.
First install the peers the web build relies on:

```bash
npm install react-dom react-native-web
```

Then configure webpack. All five pieces below are required - the docs site you
are reading uses exactly this set, and each one fails in a different way if it
is missing:

```js
// webpack.config.js
const webpack = require('webpack');

module.exports = {
  // ...
  plugins: [
    // 1. React Native code references the __DEV__ global that Metro injects
    //    and webpack does not.
    new webpack.DefinePlugin({
      __DEV__: JSON.stringify(process.env.NODE_ENV !== 'production'),
    }),
  ],
  resolve: {
    // 2. Prefer .web files, and keep webpack's own defaults.
    extensions: [
      '.web.tsx',
      '.web.ts',
      '.web.js',
      '.tsx',
      '.ts',
      '.js',
      '.mjs',
      '.json',
      '.wasm',
    ],
    alias: { 'react-native$': 'react-native-web' },
  },
  module: {
    rules: [
      {
        // 3. The parser does a dynamic `import('./wasm/md4c')` with no file
        //    extension, inside a strict-ESM build.
        test: /\.m?js$/,
        resolve: { fullySpecified: false },
      },
      {
        // 4. The emscripten glue is UMD/CommonJS shipped inside the ESM build.
        test: /md4c\.js$/,
        type: 'javascript/auto',
      },
      {
        // 5. The KaTeX loader uses `require('katex')` inside strict ESM.
        test: /lib[/\\]module[/\\]web[/\\]katex\.js$/,
        type: 'javascript/auto',
      },
    ],
  },
};
```

:::caution
Rules 4 and 5 fail **silently**. Without rule 4, webpack parses the emscripten
glue as ESM, drops its `module.exports` factory, and Markdown parsing quietly
degrades to rendering the raw source text. Without rule 5, the `require('katex')`
is left untransformed, the resulting throw is swallowed, and math renders as raw
`$...$` even with `katex` installed - with no error anywhere. Neither produces a
build failure, so check a document with math and a document with a heading
before assuming the setup is complete.
:::

Metro web works with no extra configuration - it resolves platform extensions
and injects `__DEV__` itself. **Vite, Rollup and esbuild are not verified**:
`.web` resolution alone is not enough, because they hit the same strict-ESM and
`__DEV__` problems and need equivalent handling of their own.

:::note
The `react-native$` alias is a **bundler shim**. The web entry reaches into
`react-native` for two shared style helpers (`Platform` and `processColor` in
`styleUtils`), so the specifier has to resolve to something in a browser build.
Nothing from it reaches the rendered output.
:::

### Parser (WASM)

The inlined WebAssembly parser described above decodes and compiles once, on the
first render. There is nothing to configure.

### Math (KaTeX)

LaTeX math (`md4cFlags.latexMath`, on by default) renders with
[KaTeX](https://katex.org/) in **MathML output mode**, which browsers render
natively. KaTeX is an **optional** peer dependency. When `latexMath` is on - the
default - the renderer resolves `katex` on first mount, whether or not the
document actually contains math, and it does so with a static `require`, not a
dynamic import: if the package is installed, your bundler puts it in the
renderer's chunk. Set `md4cFlags={{ latexMath: false }}` if you want it left out
entirely. Install it to enable web math:

<Tabs groupId="package-managers">
  <TabItem value="npm" label="npm">

```bash
npm install katex
```

  </TabItem>
  <TabItem value="yarn" label="yarn">

```bash
yarn add katex
```

  </TabItem>
  <TabItem value="pnpm" label="pnpm">

```bash
pnpm add katex
```

  </TabItem>
</Tabs>

If `katex` is not installed, the library skips math rendering and falls back to
the raw `$...$` / `$$...$$` source text - everything else keeps working. Setting
`md4cFlags={{ latexMath: false }}` stops math parsing altogether, so KaTeX is
never loaded.

:::note
MathML is supported natively in Chrome 109+, Firefox, and Safari; older browsers
show the raw LaTeX source as a text fallback. Importing
`katex/dist/katex.min.css` once in your web entry is **recommended** rather than
strictly required: KaTeX's stylesheet sets the font and metrics on the `.katex`
wrapper that it emits even in MathML mode, so without it equations render with
the wrong font and spacing.
:::

See [LaTeX math](/rich-text-formatting/latex-math) for the authoring syntax and
the `markdownStyle.math` / `inlineMath` options.

### Render

Import and use `EnrichedMarkdownText` as on native - the bundler serves the web
build automatically:

```tsx
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

export default function App() {
  return (
    <EnrichedMarkdownText
      markdown={'# Hello web\n\nRendered as **native** HTML.'}
    />
  );
}
```

:::caution
`containerStyle` is typed as React's `CSSProperties` here and is spread straight
onto the root `<div>`, so React Native shorthands do not apply - write
`paddingLeft`/`paddingRight` rather than `paddingHorizontal`, and
`fontWeight: 'bold'` rather than `fontWeight: 700`. The web props type also
`Omit`s `style` entirely, so `containerStyle` is the only way to style the
container.

The web build does **not** implement React Native `View` props either. Its props
type is `HTMLAttributes<HTMLDivElement>` plus `testID`, and anything it does not
recognize is spread onto the root `<div>`, so generic `ViewProps` such as
`pointerEvents` or `hitSlop` leak into the DOM and produce React unknown-prop
warnings. Use `id`, `aria-*` and CSS instead.
:::

:::note
Parsing is asynchronous: the component returns `null` until the first parse
resolves. That means one empty frame on mount, and nothing at all emitted during
server-side rendering - wrap it in a client-only boundary if your framework
pre-renders. (Style injection itself is SSR-safe.)
:::

If parsing fails, the component does not crash: it renders the raw `markdown`
string in a `<pre style="white-space: pre-wrap">` and logs the error in
development.

## Supported features

All core `EnrichedMarkdownText` features are supported on web, including:

- Full GFM: tables (with horizontal scroll), task lists (with checkbox interaction), strikethrough, links, images (block and inline), code blocks, LaTeX math (block and inline)
- [Videos](/react-native/api-reference/element-structure#videos) - a block-level `<video src="url" />` tag renders as the browser's own `<video>` element with `controls`, `playsInline` and `preload="metadata"`. All five [`markdownStyle.video`](/react-native/api-reference/style-properties#video-specific) keys apply. Neither `flavor` nor the native `enableVideo` build flag exists here, so the player is always on
- Most `markdownStyle` options - see [Ignored style keys](#ignored-style-keys) for the exceptions
- `onLinkPress`, `onLinkLongPress` (mapped to the `contextmenu` event), `onImagePress`, `onTaskListItemPress` and `onCodeBlockPress`
- `onCodeBlockPress` - makes fenced code blocks clickable and keyboard-activatable (Enter/Space) with a button role; it does not fire while code text is selected
- `onImagePress` - makes rendered images focusable and keyboard-activatable (Enter/Space) with a button role; the browser's right-click menu is preserved
- `enableTaskListItemToggle` - set to `false` to render task list checkboxes read-only (the click is fully inert: no toggle, no `onTaskListItemPress`). The checkbox keeps its normal appearance, marked `readOnly` / `aria-disabled` and made pointer-inert rather than `disabled`, matching iOS and Android
- `allowTrailingMargin`, `containerStyle`, `selectable`, `selectionColor`, `md4cFlags` (`underline`, `superscript`, `subscript`, `latexMath`, `highlight`, `hardSoftBreaks`, `preserveBlankLines`, `admonitions`)
- GitHub admonitions (`> [!NOTE]`) - rendered as callouts with the same icon set and `blockquote.admonitions` palette as native. There is no `flavor` prop on web, so they are always on unless `md4cFlags={{ admonitions: false }}`
- RTL support via the `dir` prop (CSS logical properties automatically flip blockquote borders, list indentation, etc.)
- Arbitrary DOM attributes, which pass through to the root `<div>`

### Ignored style keys

Most of `markdownStyle` applies, but these keys are accepted and ignored:

| Key | Why |
| --- | --- |
| `codeBlock.syntaxColors` | Code blocks are not syntax-highlighted on web, so per-token colors have nothing to color |
| all of `spoiler` | Spoilers are not rendered at all - see [Not supported on web](#not-supported-on-web) |
| `list.bulletColor`, `list.bulletSize`, `list.markerMinWidth`, `list.markerColor`, `list.markerFontWeight`, `list.gapWidth` | Web leaves list markers to the browser's `::marker`. Of the `list` keys only `fontSize`, `fontFamily`, `fontWeight`, `color`, `lineHeight`, `marginTop`, `marginBottom`, `marginLeft` and `itemSpacing` are read |
| `table.horizontalOverflow` | Web tables are always `overflow-x: auto` |
| `taskList.borderColor`, `taskList.checkmarkColor` | The checkbox is the browser's native control, tinted through `accentColor` (`checkedColor`) only |

### Accessibility

- Semantic HTML elements for all Markdown structures. Two near-misses worth knowing: admonitions are a `<div>` rather than an `<aside>`, and a paragraph inside a list item renders as a `<span>`.
- Images: `alt` text falls back to `title`, then URL filename, then `"Image"`
- Code blocks: `aria-label` with language when available (e.g. `"Code block: python"`)
- Math: `role="math"` and `aria-label` with the expression source, on both the KaTeX MathML output and the plain-text fallback
- Task list checkboxes: `aria-label` with the task text (e.g. `"Task: Buy groceries"`)
- Videos: `aria-label` from the tag's text content, falling back to `title`, then `"Video"`

:::caution
Every one of those strings is **hard-coded English** on web, and
[`accessibilityLabels`](/react-native/api-reference/enriched-markdown-text#accessibilitylabels) - the prop that localizes them on native - is stripped here.
There is no way to translate them today, which is a hard limit for non-English
apps. Setting `onCodeBlockPress` or `onImagePress` also puts `role="button"` on
the `<pre>` / `<img>`, which replaces their code and image semantics.
:::

### Web-only props

| Prop     | Description                                                                                                                                               |
| -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `dir`    | Sets the text direction on the root container (`'ltr'`, `'rtl'`, or `'auto'`). CSS logical properties in the renderers automatically flip layout for RTL. |
| `testID` | Rendered as `data-testid`, so DOM testing libraries can query it.                                                                                         |

The web entry point exports its own `EnrichedMarkdownTextProps` type. It drops
the native-only props and `style`, and adds the ones above. Note that `dir` is
declared on **both** the native and the web props type - deliberately, so a
project typed against the native interface can pass it without switching types.
It is a no-op on native.

## Ignored props (native-only)

These props are recognized and **stripped** before anything reaches the DOM, so
passing them is harmless but has no effect. The list is derived from the type, so
it is exactly the native-only surface:

| Prop                                         | Reason                                                                                                                                                                                                  |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `flavor`                                     | The web renderer always uses full GFM capabilities. On native, `flavor` controls whether a single text view (CommonMark) or a container-based renderer (GitHub) is used; the DOM has no such constraint. |
| `enableLinkPreview`                          | iOS-only feature (native link preview on long press).                                                                                                                                                   |
| `enableBlockContextMenu`                     | The long-press block menu is a native interaction.                                                                                                                                                      |
| `allowFontScaling` / `maxFontSizeMultiplier` | React Native text scaling props. Browsers handle font scaling through zoom and OS accessibility settings instead.                                                                                       |
| `streamingAnimation`                         | Native-only tail fade-in animation. Not yet implemented on web.                                                                                                                                         |
| `streamingConfig`                            | Native-only streaming block handling. Not yet implemented on web.                                                                                                                                       |
| `spoilerOverlay`                             | There is no spoiler renderer on web.                                                                                                                                                                    |
| `contextMenuItems`                           | Not supported - browsers don't allow extending the native context menu.                                                                                                                                 |
| `selectionMenuConfig`                        | Not supported - native-only built-in selection menu actions.                                                                                                                                            |
| `onCopyPress`                                | There is no code-block header or copy button on web, so it can never fire.                                                                                                                              |
| `onLatexError`                               | Web renders math through KaTeX and does not report failures through this callback.                                                                                                                      |
| `imageRequestHeaders`                        | Browsers do not allow custom headers on `<img>` requests.                                                                                                                                               |
| `accessibilityLabels`                        | The web a11y strings are hard-coded - see the caution above.                                                                                                                                            |
| `selectionHandleColor`                       | Android-only - desktop browsers don't render selection handles.                                                                                                                                         |
| `textBreakStrategy`                          | Android-only line-breaking control.                                                                                                                                                                     |
| `lineBreakStrategyIOS`                       | iOS-only line-breaking control.                                                                                                                                                                         |
| `writingDirection`                           | Native per-paragraph direction resolution. Use [`dir`](#web-only-props) on web.                                                                                                                         |
| `numberOfLines` / `ellipsizeMode`            | The web build does not clamp.                                                                                                                                                                           |

:::caution
Only the library's **own** props are stripped. Generic React Native `ViewProps`
are not, so they are forwarded to the root `<div>` and React will warn about
unknown DOM attributes. Use `id`, `aria-label` and CSS rather than `nativeID`,
`accessibilityLabel` and `style`.
:::

## Not supported on web

:::danger
**Spoilers delete their content.** The parser emits a spoiler node, the web
renderer has no entry for it, and an unhandled node is dropped together with its
whole subtree - so `a ||secret|| b` renders as `a  b`. The concealed text is
gone, not concealed. Do not put content behind a spoiler if the same Markdown is
rendered on web.
:::

- `EnrichedMarkdownTextInput` - native-only today; **web support is coming soon** (see the [roadmap](/misc/roadmap)). Importing it from the web entry point yields `undefined`.
- Code-block syntax highlighting - fenced code blocks render as plain monospaced text with no per-token colors, no header bar and no copy button
- Configurable link `target` - all links open in a new tab (`target="_blank" rel="noopener noreferrer"`). Use `onLinkPress` for custom navigation.
- Line clamping - `numberOfLines` and `ellipsizeMode` are native-only and are not part of the web props type
- Clipboard integration - the web build never writes to the clipboard, so none of the [copy options](/user-experience/copy-options) apply
