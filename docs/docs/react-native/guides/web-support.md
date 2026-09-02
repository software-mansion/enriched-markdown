---
sidebar_label: Web support
sidebar_position: 1
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Web support

`EnrichedMarkdownText` runs on web using [`react-native-web`](https://necolas.github.io/react-native-web/)
for the React Native primitives and [md4c](https://github.com/mity/md4c)
compiled to WebAssembly for parsing. The WASM binary is bundled in the npm
package - no build step is required by consumers.

The web renderer uses semantic HTML elements (`<p>`, `<h1>`-`<h6>`,
`<blockquote>`, `<ul>`, `<ol>`, `<table>`, etc.) for improved accessibility.

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

Web rendering runs through [`react-native-web`](https://necolas.github.io/react-native-web/),
so your app needs a web build. Follow the path that matches your project.

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

#### Bare React Native (webpack)

Without Expo, wire up `react-native-web` in your bundler. With webpack, alias
`react-native` to `react-native-web` and make sure the resolver prefers `.web`
files, so the library's web entry is chosen over its native one:

```js
// webpack.config.js
module.exports = {
  // ...
  resolve: {
    alias: { 'react-native$': 'react-native-web' },
    extensions: ['.web.tsx', '.web.ts', '.web.js', '.tsx', '.ts', '.js'],
  },
};
```

See the [react-native-web multi-platform guide](https://necolas.github.io/react-native-web/docs/multi-platform/)
for a complete webpack + Babel example. Metro web and Vite (with a
`react-native-web` plugin) work as well, as long as `.web` extensions resolve.

### Parser (WASM)

The md4c parser ships as a WebAssembly binary inlined into the JavaScript
bundle, so there is no separate `.wasm` asset to host or configure. It decodes
and compiles once, on the first render.

### Math (KaTeX)

LaTeX math (`md4cFlags.latexMath`, on by default) renders with
[KaTeX](https://katex.org/), an **optional** peer dependency. To show math on
web, install it and import its stylesheet once (for example in your web entry
file):

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

```tsx
import 'katex/dist/katex.min.css';
```

If `katex` is not installed, the library skips math rendering and falls back to
the raw `$...$` / `$$...$$` source text - everything else keeps working.

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
- `onLinkPress`, `onLinkLongPress` (mapped to `contextmenu` event), `onImagePress`, `onTaskListItemPress` callbacks
- `onImagePress` - makes rendered images focusable and keyboard-activatable (Enter/Space) with a button role; the browser's right-click menu is preserved
- `enableTaskListItemToggle` - set to `false` to render task list checkboxes read-only (the click is fully inert: no toggle, no `onTaskListItemPress`). The checkbox keeps its normal appearance, marked `readOnly` / `aria-disabled` and made pointer-inert rather than `disabled`, matching iOS and Android
- `allowTrailingMargin`, `containerStyle`, `selectable`, `selectionColor`, `md4cFlags` (`underline`, `superscript`, `subscript`, `latexMath`, `highlight`, `hardSoftBreaks`, `preserveBlankLines`)
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
