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
WebAssembly. The WASM binary is inlined as base64 inside the JavaScript bundle
(`SINGLE_FILE=1`), so there is no separate `.wasm` asset to host or configure
and no build step is required by consumers.

:::note
Web support currently applies to `EnrichedMarkdownText` (the renderer).
`EnrichedMarkdownTextInput` (the editor) is native-only today, with **web
support coming soon**. See the [Feature support](/introduction/supported-features)
overview for the full matrix.
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

Without Expo, point your resolver at the `.web` files. With webpack:

```js
// webpack.config.js
module.exports = {
  // ...
  resolve: {
    extensions: ['.web.tsx', '.web.ts', '.web.js', '.tsx', '.ts', '.js'],
    alias: { 'react-native$': 'react-native-web' },
  },
};
```

Metro web and Vite work as well, as long as `.web` extensions resolve first.

:::note
The alias above is a **bundler shim**. The web entry reaches into `react-native`
for two shared style helpers (`Platform` and `processColor` in `styleUtils`), so
the specifier has to resolve to something in a browser build. Nothing from it
reaches the rendered output.
:::

### Parser (WASM)

The md4c parser ships as a WebAssembly binary inlined into the JavaScript bundle
as base64 (`SINGLE_FILE=1`), so there is no separate `.wasm` asset to host or
configure. It decodes and compiles once, on the first render.

### Math (KaTeX)

LaTeX math (`md4cFlags.latexMath`, on by default) renders with
[KaTeX](https://katex.org/) in **MathML output mode**, which browsers render
natively - no CSS or font files required. KaTeX is an **optional** peer
dependency, loaded lazily the first time a math node is encountered, so it has
no cost on pages without math. Install it to enable web math:

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
show the raw LaTeX source as a text fallback. Unlike some KaTeX setups, no
stylesheet or `<link>` tag is needed - import `katex/dist/katex.min.css` once in
your web entry only if you want KaTeX's own fonts applied to the MathML output.
:::

See [LaTeX math](/rich-text-formatting/latex-math) for the authoring syntax and
the `markdownStyle.math` / `inlineMath` options.

### Render

Import and use `EnrichedMarkdownText` exactly as on native - the bundler serves
the web build automatically:

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

## Supported features

All core `EnrichedMarkdownText` features are supported on web, including:

- Full GFM: tables (with horizontal scroll), task lists (with checkbox interaction), strikethrough, links, images (block and inline), code blocks, LaTeX math (block and inline)
- Almost all `markdownStyle` options. The exceptions are `codeBlock.syntaxColors` (code blocks are not syntax-highlighted on web, so per-token colors have no effect) and `spoiler` styling (spoilers are not rendered on web yet)
- `onLinkPress`, `onLinkLongPress` (mapped to `contextmenu` event), `onImagePress`, `onTaskListItemPress`, `onCodeBlockPress` callbacks
- `onCodeBlockPress` - makes fenced code blocks clickable and keyboard-activatable (Enter/Space) with a button role; it does not fire while code text is selected
- `onImagePress` - makes rendered images focusable and keyboard-activatable (Enter/Space) with a button role; the browser's right-click menu is preserved
- `enableTaskListItemToggle` - set to `false` to render task list checkboxes read-only (the click is fully inert: no toggle, no `onTaskListItemPress`). The checkbox keeps its normal appearance, marked `readOnly` / `aria-disabled` and made pointer-inert rather than `disabled`, matching iOS and Android
- `allowTrailingMargin`, `containerStyle`, `selectable`, `selectionColor`, `md4cFlags` (`underline`, `superscript`, `subscript`, `latexMath`, `highlight`, `hardSoftBreaks`, `preserveBlankLines`, `admonitions`)
- GitHub admonitions (`> [!NOTE]`) - rendered as callouts with the same icon set and `blockquote.admonitions` palette as native. There is no `flavor` prop on web, so they are always on unless `md4cFlags={{ admonitions: false }}`
- RTL support via the `dir` prop (CSS logical properties automatically flip blockquote borders, list indentation, etc.)

### Accessibility

- Semantic HTML elements for all markdown structures
- Images: `alt` text falls back to `title`, then URL filename, then `"Image"`
- Code blocks: `aria-label` with language when available (e.g. `"Code block: python"`)
- Math: `role="math"` and `aria-label` with the expression source, on both the KaTeX MathML output and the plain-text fallback
- Task list checkboxes: `aria-label` with the task text (e.g. `"Task: Buy groceries"`)

### Web-only props

| Prop  | Description                                                                                                                                               |
| ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `dir` | Sets the text direction on the root container (`'ltr'`, `'rtl'`, or `'auto'`). CSS logical properties in the renderers automatically flip layout for RTL. |

The web entry point exports its own `EnrichedMarkdownTextProps` type that
includes these web-only props in place of the native-only ones.

## Ignored props (native-only)

| Prop                                         | Reason                                                                                                                                                                                                  |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `flavor`                                     | The web renderer always uses full GFM capabilities. On native, `flavor` controls whether a single `TextView` (CommonMark) or container-based renderer (GitHub) is used; the DOM has no such constraint. |
| `enableLinkPreview`                          | iOS-only feature (native link preview on long press).                                                                                                                                                   |
| `allowFontScaling` / `maxFontSizeMultiplier` | React Native text scaling props. Browsers handle font scaling natively via OS accessibility settings.                                                                                                   |
| `streamingAnimation`                         | Native-only tail fade-in animation. Not yet implemented on web.                                                                                                                                         |
| `streamingConfig`                            | Native-only streaming table configuration. Not yet implemented on web.                                                                                                                                  |
| `contextMenuItems`                           | Not supported - browsers don't allow extending the native context menu.                                                                                                                                 |
| `selectionMenuConfig`                        | Not supported - native-only built-in selection menu actions.                                                                                                                                            |
| `selectionHandleColor`                       | Android-only - desktop browsers don't render selection handles.                                                                                                                                         |

## Not supported on web

- `EnrichedMarkdownTextInput` - native-only today; **web support is coming soon**
- Code-block syntax highlighting - fenced code blocks render as plain monospaced text (no per-token colors); the `codeBlock.syntaxColors` style is ignored
- Spoiler concealment (`||text||`) - the spoiler overlay is not rendered on web yet, so `spoiler` styling and `spoilerOverlay` have no effect
- Configurable link `target` - all links open in a new tab (`target="_blank"`). Use `onLinkPress` for custom navigation.
- Videos - the `<video>` tag is parsed on native only; on web it renders nothing
- Line clamping - `numberOfLines` and `ellipsizeMode` are native-only and are not part of the web props type
- `onLatexError` - web renders math through KaTeX and does not report failures through this callback
