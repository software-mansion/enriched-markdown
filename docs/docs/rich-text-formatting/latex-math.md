---
sidebar_label: LaTeX math
sidebar_position: 2
---

import MathSrc from '!!raw-loader!@site/src/examples/react-native/rich-text-formatting/latex-math/Math';

# LaTeX math

`EnrichedMarkdownText` renders LaTeX math natively, both inline and as block equations:

- **Inline math** (`$...$`) flows within the surrounding text and works in either flavor.
- **Block math** (`$$...$$`) renders as a standalone display equation. A display block needs the segmented renderer, so it requires [`flavor="github"`](/react-native/guides/markdown-flavors) - in `commonmark`, a `$$...$$` on its own line falls back to inline typesetting.

Math parsing is **on by default**. You can turn it off so `$` is treated as plain text, and exclude the native math engine to shrink your binary - see [Reducing app size](#reducing-app-size).

## Usage

<CodeTabs groupId="platform">
<Tab label="React Native">

<LivePreview src={MathSrc} />

</Tab>
<Tab label="iOS">

On the standalone iOS SDK, math is **off** until you add the optional `EnrichedMarkdownLaTeX` product and enable it per view. There is no `MarkdownParsingOptions` field for it: the modifier switches parsing and rendering on together, so `$…$` stays plain text without it.

```swift
import EnrichedMarkdown
import EnrichedMarkdownLaTeX

EnrichedMarkdownText(content)
  .markdownLaTeX()
  .markdownTheme {
    MathBlock().font(size: 22)
    InlineMath().foregroundStyle(.tint)
  }
```

Display math needs no flavor switch - a `$$…$$` on its own line always renders as a panel, scrolling horizontally when the formula is wider than the line. See [LaTeX math](/ios/guides/latex-math).

</Tab>
<Tab label="Android"><ComingSoon platform="Android" /></Tab>
</CodeTabs>

Block equations render as standalone display elements with their own spacing and an optional background (`markdownStyle.math`); inline math inherits the surrounding block's typography and takes only a color (`markdownStyle.inlineMath`).

:::important
LaTeX commands use backslashes (`\frac`, `\alpha`). In regular JS strings and template literals a backslash is an escape character, so use `String.raw` (as above) or double every backslash (`\\frac`). Block math (`$$...$$`) must be on its own line to render as a display element.
:::

## Handling render errors {#handling-render-errors}

When the engine cannot draw a formula - an unsupported command, a syntax error -
it does not crash or leave a gap: the expression falls back to displaying its raw
source. Pass
[`onLatexError`](/react-native/api-reference/enriched-markdown-text#onlatexerror)
to observe those failures, for example to report them to an error tracker:

```tsx
<EnrichedMarkdownText
  markdown={String.raw`Inline $\nosuchcommand$ and block:` + '\n\n$$\\bar$$'}
  onLatexError={({ source, message, displayMode }) => {
    reportToErrorTracker('latex-render-failed', { source, message, displayMode });
  }}
/>
```

The whole expression is the unit of failure - the engine either renders one in
full or rejects it - so the callback reports the failing `source` rather than a
single offending command. Classify `source` on your side instead of keeping an
allowlist that goes stale when the engine is upgraded.

Each component instance remembers what it has already reported, keyed by
`displayMode` + `source`, and fires **at most once per distinct failing
expression**. That cache survives `markdown` changes, so streaming content
reports each failure once instead of on every token.

:::caution
The de-duplication is per component **instance**, not global. A remount - navigating
away and back, a changed React `key`, or list virtualization recycling the row -
creates an instance with no memory of earlier reports and fires again for the same
expressions. De-duplicate by `source` on your side if you aggregate these app-wide.
:::

## Reducing app size

Native LaTeX rendering relies on [RaTeX](https://ratex.lites.dev/), a KaTeX-compatible math engine bundled by default on iOS and Android. If you don't need math, you can stop parsing it or exclude the native engine entirely to shrink your binary. The exact configuration is platform-specific - see the [Reference](#reference).

:::note
LaTeX math is not yet enabled on macOS.
:::

## Reference

<CodeTabs groupId="platform">
<Tab label="React Native">

- [`md4cFlags.latexMath`](/react-native/api-reference/enriched-markdown-text#latexmath) - toggle math parsing (on by default).
- [`markdownStyle.math`](/react-native/api-reference/style-properties#math-block-specific) and [`inlineMath`](/react-native/api-reference/style-properties#inline-math-specific) - display and inline equation styling.
- [`onLatexError`](/react-native/api-reference/enriched-markdown-text#onlatexerror) - observe expressions the engine could not render; see [Handling render errors](#handling-render-errors).
- **Reduce app size** - set `md4cFlags={{ latexMath: false }}` to stop parsing, or `"enableMath": false` in the `enriched-markdown` block of your `package.json` to exclude RaTeX from the native build. See [Native assets](/react-native/guides/native-assets#reducing-binary-size) for the full opt-out.
- **Web** - math renders through KaTeX, an optional peer dependency. See [Web support](/react-native/guides/web-support#math-katex).

</Tab>
<Tab label="iOS">

- [`.markdownLaTeX()`](/ios/guides/latex-math#turning-it-on) - enable math parsing and rendering; math is off without it.
- [`MathBlock()` and `InlineMath()`](/ios/guides/latex-math#styling) - display and inline equation styling.
- **Render errors** - there is no error callback; a formula that fails to typeset falls back to its delimited source.
- **Reduce app size** - simply omit the `EnrichedMarkdownLaTeX` product. The base package links no math engine, so nothing to opt out of.

</Tab>
<Tab label="Android"><ComingSoon platform="Android" /></Tab>
</CodeTabs>
