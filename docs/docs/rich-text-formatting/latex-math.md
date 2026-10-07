---
sidebar_label: LaTeX math
sidebar_position: 3
---

import MathSrc from '!!raw-loader!@site/src/examples/react-native/rich-text-formatting/latex-math/Math';

# LaTeX math

`EnrichedMarkdownText` renders LaTeX math natively, both inline and as block equations:

- **Inline math** (`$...$`) flows within the surrounding text and works in either flavor.
- **Block math** (`$$...$$`) renders as a standalone display equation. On iOS and Android a display block needs the segmented renderer, so it requires [`flavor="github"`](/react-native/guides/markdown-flavors) - in `commonmark`, a `$$...$$` on its own line falls back to inline typesetting. The web build has no `flavor` prop and always renders `$$` as a block.

Math parsing is **on by default**. You can turn it off so `$` is treated as plain text, and exclude the native math engine to shrink your binary - see [Reducing app size](#reducing-app-size).

## Usage

<LivePreview src={MathSrc} />

{/* UNRELEASED PLATFORMS: the standalone iOS SDK ships math as an optional
`EnrichedMarkdownLaTeX` product enabled per view with `.markdownLaTeX()` and
styled through `MathBlock()` / `InlineMath()`; display math there needs no
flavor switch. The standalone Android SDK parses `$...$` but has no math
renderer yet. Restore those tabs, and the links to /ios/guides/latex-math, when
those packages ship. */}

Block equations render as standalone display elements with their own spacing and an optional background. The style key is `math` (not `mathBlock`) and it takes `fontSize`, `color`, `backgroundColor`, `padding`, `marginTop`, `marginBottom` and `textAlign`. Inline math inherits the surrounding block's typography and takes only a color, through `markdownStyle.inlineMath`. Under `flavor="commonmark"` **none** of the `math` keys apply, because the equation becomes an inline attachment coloured from `inlineMath`.

:::important
LaTeX commands use backslashes (`\frac`, `\alpha`). In regular JS strings and template literals a backslash is an escape character, so either double every backslash (`\\frac`, as the example above does) or wrap the string in `String.raw`. Block math (`$$...$$`) must be on its own line to render as a display element.
:::

## Handling render errors {#handling-render-errors}

When the engine cannot draw a formula - an unsupported command, a syntax error -
it does not crash or leave a gap. On iOS and Android the expression falls back to
its raw source **with the delimiters put back** (`$\nosuchcommand$`); on web you
get KaTeX's own error output instead, or the delimited source when `katex` is not
installed. Pass
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

:::note
`onLatexError` is native-only. It is stripped on web, where KaTeX renders its own
error markup instead and nothing is reported back to you.
:::

The whole expression is the unit of failure - the engine either renders one in
full or rejects it - so the callback reports the failing `source` rather than a
single offending command. Classify `source` on your side instead of keeping an
allowlist that goes stale when the engine is upgraded.

Each component instance remembers what it has already reported, keyed by
`displayMode` + `source`, and fires **at most once per distinct failing
expression**. That cache survives `markdown` changes, so streaming content
reports each failure once instead of on every token.

:::caution
The de-duplication is per component **instance**, not global, and it cuts both ways.
A remount - navigating away and back, or a changed React `key` - creates an instance
with no memory of earlier reports and fires again for the same expressions. A
**recycled** instance is the opposite case: list virtualization reuses the native
view without clearing the cache, so a row that scrolls back into view with different
content stays silent about a failure it has already reported. De-duplicate by
`source` on your side if you aggregate these app-wide.
:::

## Reducing app size

Native LaTeX rendering relies on [RaTeX](https://ratex.lites.dev/), a KaTeX-compatible math engine that the React Native package bundles by default on iOS and Android. If you don't need math, you can stop parsing it or exclude the native engine entirely to shrink your binary - see the [Reference](#reference).

:::danger
**Block math is silently dropped on macOS.** Inline `$...$` renders there, but a
display `$$...$$` under `flavor="github"` produces no output and no fallback text -
the equation simply disappears. Math is otherwise compiled into macOS builds by
default (there is no macOS gate on the engine), it is just unvalidated. See
[macOS support](/react-native/guides/macos).
:::

## Reference

- [`md4cFlags.latexMath`](/react-native/api-reference/enriched-markdown-text#latexmath) - toggle math parsing (on by default).
- [`markdownStyle.math`](/react-native/api-reference/style-properties#math-block-specific) and [`inlineMath`](/react-native/api-reference/style-properties#inline-math-specific) - display and inline equation styling.
- [`onLatexError`](/react-native/api-reference/enriched-markdown-text#onlatexerror) - observe expressions the engine could not render; see [Handling render errors](#handling-render-errors).
- **Reduce app size** - set `md4cFlags={{ latexMath: false }}` to stop parsing, or `"enableMath": false` in the `enriched-markdown` block of your `package.json` to exclude the engine from the native build on both iOS and Android. See [Native assets](/react-native/guides/native-assets#reducing-binary-size) for the full opt-out.
- **Web** - math renders through KaTeX, an optional peer dependency. Without it installed, equations fall back to their raw `$...$` source. See [Web support](/react-native/guides/web-support#math-katex).

{/* UNRELEASED PLATFORMS: standalone iOS reference entries lived here -
`.markdownLaTeX()`, `MathBlock()` / `InlineMath()`, no error callback, and
"omit the EnrichedMarkdownLaTeX product" as the size opt-out. */}
