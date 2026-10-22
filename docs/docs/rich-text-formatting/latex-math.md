---
sidebar_label: LaTeX math
sidebar_position: 2
---

import MathSrc from '!!raw-loader!@site/src/examples/react-native/rich-text-formatting/latex-math/Math';

# LaTeX math

`EnrichedMarkdownText` renders LaTeX math natively, both inline and as block equations:

- **Inline math** (`$...$` or `\(...\)`) flows within the surrounding text and works in either flavor.
- **Block math** (`$$...$$` or `\[...\]`) renders as a standalone display equation. In the React Native package on iOS and Android, a display block needs the segmented renderer, so it requires [`flavor="github"`](/react-native/guides/markdown-flavors) - in `commonmark`, a `$$...$$` on its own line falls back to inline typesetting. The web build has no `flavor` prop and always renders `$$` as a block, and the standalone iOS and Android SDKs need no flavor switch either.

In the React Native package math parsing is **on by default**. You can turn it off so `$` is treated as plain text, and exclude the native math engine to shrink your binary - see [Reducing app size](#reducing-app-size). The standalone iOS and Android SDKs ship math as an optional add-on instead, off until you install and enable it.

## Usage

<CodeTabs groupId="platform">
<Tab label="React Native">

<LivePreview src={MathSrc} />

</Tab>
<Tab label="iOS">

Math is the optional `EnrichedMarkdownLaTeX` product. Add it alongside `EnrichedMarkdown`, then enable it per view with `.markdownLaTeX()` - that one modifier turns on parsing **and** rendering, as there is no parsing option for math. Display math needs no flavor switch.

```swift
import EnrichedMarkdown
import EnrichedMarkdownLaTeX
import SwiftUI

struct FormulaView: View {
  let content: String

  var body: some View {
    EnrichedMarkdownText(content)
      .markdownLaTeX()
  }
}
```

Style equations through the `MathBlock()` and `InlineMath()` theme elements. See the [iOS LaTeX math guide](/ios/guides/latex-math) for setup, [styling](/ios/guides/latex-math#styling) and accessibility.

</Tab>
<Tab label="Android">

Math is the optional `com.swmansion.enriched.markdown:math` artifact. Enabling `LatexMathPlugin` turns on parsing **and** rendering - there is no parsing option for math. Without the plugin, `$...$` is ordinary text. Display math needs no flavor switch.

```kotlin
LatexMathPlugin {
  EnrichedMarkdownText(markdown = content)
}
```

The `LatexMathPlugin { }` scope enables the plugin for everything beneath it; to enable it on a single instance, pass `plugins = listOf(LatexMathPlugin)` to that `EnrichedMarkdownText` instead. Style equations with `math { }` and `inlineMath { }` inside `markdownStyle { }`. See the [Android LaTeX math guide](/android/guides/latex-math) for installation and [styling](/android/guides/latex-math#styling).

</Tab>
</CodeTabs>


Block equations render as standalone display elements with their own spacing and an optional background. In the React Native package the style key is `math` (not `mathBlock`) and it takes `fontSize`, `color`, `backgroundColor`, `padding`, `marginTop`, `marginBottom` and `textAlign`. Inline math inherits the surrounding block's typography and takes only a color, through `markdownStyle.inlineMath`. Under `flavor="commonmark"` **none** of the `math` keys apply, because the equation becomes an inline attachment coloured from `inlineMath`.

:::important
Bracket delimiters use the same math parsing flag and native rendering plugin as dollar delimiters. Use a raw string to preserve the backslashes in JavaScript:

```js
String.raw`Answer: \(x_1 + 1\).`;
```

To show literal bracket delimiters, double their backslashes in the Markdown source. Unmatched delimiters follow ordinary Markdown escaping until the closing delimiter arrives.

LaTeX commands use backslashes (`\frac`, `\alpha`). In regular JS strings and template literals a backslash is an escape character, so either double every backslash (`\\frac`, as the example above does) or wrap the string in `String.raw`. Block math (`$$...$$`) must be on its own line to render as a display element.
:::

## Handling render errors {#handling-render-errors}

When the engine cannot draw a formula - an unsupported command, a syntax error -
it does not crash or leave a gap. On iOS and Android the expression falls back to
its raw source **with the delimiters put back** (`$\nosuchcommand$`); on web you
get KaTeX's own error output instead, or the delimited source when `katex` is not
installed. Pass
[`onLatexError`](/react-native/api-reference/enriched-markdown-text#onlatexerror)
to observe those failures in the React Native package, for example to report them to an error tracker:

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

On the standalone SDKs the fallback to the delimited source is the same. iOS has no error callback; Android reports each failure through `onPluginEvent` as a `LatexError` - see [Errors](/android/guides/latex-math#errors).

## Reducing app size

Native LaTeX rendering relies on [RaTeX](https://ratex.lites.dev/), a KaTeX-compatible math engine that the React Native package bundles by default on iOS and Android. If you don't need math, you can stop parsing it or exclude the native engine entirely to shrink your binary - see the [Reference](#reference). On the standalone SDKs math is opt-in already: leave out the `EnrichedMarkdownLaTeX` product (iOS) or the `math` artifact (Android) and no engine ships.

:::danger
**Block math is silently dropped on macOS in the React Native package.** Inline `$...$` renders there, but a
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

**iOS** - see the [LaTeX math guide](/ios/guides/latex-math).

- [`.markdownLaTeX()`](/ios/guides/latex-math#turning-it-on) - enables parsing and rendering per view; its `accessibilityLabel:` parameter sets the [VoiceOver label](/ios/guides/latex-math#accessibility).
- [`MathBlock()`](/ios/guides/latex-math#mathblock) and [`InlineMath()`](/ios/guides/latex-math#inlinemath) - display and inline equation styling.
- **Errors** - there is no error callback; a formula that fails to typeset renders as its delimited source.
- **Reduce app size** - omit the `EnrichedMarkdownLaTeX` product.

**Android** - see the [LaTeX math guide](/android/guides/latex-math).

- [`LatexMathPlugin`](/android/guides/latex-math#turning-it-on) - enables parsing and rendering, for a subtree (`LatexMathPlugin { }`) or one view (the [`plugins`](/android/api-reference/enriched-markdown-text#plugins) parameter).
- [`math { }` and `inlineMath { }`](/android/guides/latex-math#styling) - display and inline equation styling.
- [`onPluginEvent`](/android/guides/latex-math#errors) - render failures arrive as a `LatexError(source, message, displayMode)` event.
- **Reduce app size** - omit the `math` artifact. It is also the only artifact without a 32-bit `x86` native library; see [Installing the artifact](/android/guides/latex-math#installation).

