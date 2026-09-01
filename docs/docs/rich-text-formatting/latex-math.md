---
sidebar_label: LaTeX math
sidebar_position: 2
---

# LaTeX math

`EnrichedMarkdownText` renders LaTeX math natively, both inline and as block equations:

- **Inline math** (`$...$`) flows within the surrounding text and works in either flavor.
- **Block math** (`$$...$$`) renders as a standalone display equation. A display block needs the segmented renderer, so it requires [`flavor="github"`](/rich-text-formatting/markdown-flavors) - in `commonmark`, a `$$...$$` on its own line falls back to inline typesetting.

Math parsing is **on by default**. You can turn it off so `$` is treated as plain text, and exclude the native math engine to shrink your binary - see [Reducing app size](#reducing-app-size).

## Usage

<CodeTabs groupId="platform">
<Tab label="React Native">

```tsx
<EnrichedMarkdownText
  flavor="github"
  markdown={String.raw`
The quadratic formula:

$$x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}$$

Einstein's mass-energy equivalence $E = mc^2$ is famous.
`}
  markdownStyle={{
    math: {
      fontSize: 20,
      color: '#1F2937',
      backgroundColor: '#F3F4F6',
      padding: 12,
      textAlign: 'center',
    },
    inlineMath: { color: '#1F2937' },
  }}
/>
```

</Tab>
<Tab label="iOS"><ComingSoon platform="iOS" /></Tab>
<Tab label="Android"><ComingSoon platform="Android" /></Tab>
</CodeTabs>

Block equations render as standalone display elements with their own spacing and an optional background (`markdownStyle.math`); inline math inherits the surrounding block's typography and takes only a color (`markdownStyle.inlineMath`).

:::important
LaTeX commands use backslashes (`\frac`, `\alpha`). In regular JS strings and template literals a backslash is an escape character, so use `String.raw` (as above) or double every backslash (`\\frac`). Block math (`$$...$$`) must be on its own line to render as a display element.
:::

## Web

On web the library renders LaTeX with [KaTeX](https://katex.org/) in **MathML output mode**, which browsers render natively - no CSS or font files required. KaTeX is an **optional peer dependency**, loaded lazily the first time a math node is encountered, so it has no cost on pages without math. Install it to enable web math:

<CodeTabs groupId="package-managers">
<Tab label="npm">npm install katex</Tab>
<Tab label="yarn">yarn add katex</Tab>
<Tab label="pnpm">pnpm add katex</Tab>
</CodeTabs>

:::note
MathML is supported natively in Chrome 109+, Firefox, and Safari; older browsers show the raw LaTeX source as a text fallback. If `katex` is not installed, math rendering is skipped and the raw `$...$` / `$$...$$` source is shown. Unlike some KaTeX setups, no stylesheet or `<link>` tag is needed.
:::

## Reducing app size

Native LaTeX rendering relies on RaTeX, a KaTeX-compatible math engine bundled by default on iOS and Android. If you don't need math, you can stop parsing it or exclude the native engine entirely to shrink your binary. The exact configuration is platform-specific - see the [Reference](#reference).

:::note
LaTeX math is not yet enabled on macOS.
:::

## Reference

<CodeTabs groupId="platform">
<Tab label="React Native">

- [`md4cFlags.latexMath`](/react-native/api-reference/enriched-markdown-text#latexmath) - toggle math parsing (on by default).
- [`markdownStyle.math`](/react-native/api-reference/style-properties) and `inlineMath` - display and inline equation styling.
- **Reduce app size** - set `md4cFlags={{ latexMath: false }}` to stop parsing (also skips KaTeX on web), or `"enableMath": false` in the `enriched-markdown` block of your `package.json` to exclude RaTeX from the native build. See [Native assets](/react-native/guides/native-assets#reducing-binary-size) for the full opt-out.

</Tab>
<Tab label="iOS"><ComingSoon platform="iOS" /></Tab>
<Tab label="Android"><ComingSoon platform="Android" /></Tab>
</CodeTabs>
