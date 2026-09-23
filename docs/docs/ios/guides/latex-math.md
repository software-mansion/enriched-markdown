---
sidebar_label: LaTeX math
sidebar_position: 2
---

# LaTeX math

Math rendering ships as a **separate product**, `EnrichedMarkdownLaTeX`, so an app that never shows a formula does not link a typesetting engine it will not use. The engine is a prebuilt binary dependency plus the KaTeX font files - a few megabytes of app size - which is why it is opt-in rather than part of the base package.

The consequence to know up front: without the product, `$…$` is not math syntax at all. There is no `MarkdownParsingOptions` field for it, so `$x^2$` stays plain text and nothing is lost or mangled. Adding the product turns the parsing **and** the rendering on together, in one modifier.

## Turning it on

Add the `EnrichedMarkdownLaTeX` product alongside `EnrichedMarkdown` (see [Installation](/ios/basics/installation#the-two-products)), then enable it per view:

```swift
import EnrichedMarkdown
import EnrichedMarkdownLaTeX
import SwiftUI

struct FormulaView: View {
  var body: some View {
    EnrichedMarkdownText(content)
      .markdownLaTeX()
  }
}
```

Like every other modifier, it reads from the environment, so applying it to a container enables math for every `EnrichedMarkdownText` beneath it.

## What renders

- **`$…$`** typesets inline, at the size of the surrounding text.
- **`$$…$$`** on its own line renders as a full-width panel. A formula wider than the line **scrolls horizontally in place**, and keeps its scroll position across re-renders.

```markdown
The area is $\pi r^2$, and the general form is:

$$
\int_{0}^{1} x^2 \,dx = \frac{1}{3}
$$
```

Source that fails to typeset falls back to the **delimited text** - `$\frac{1}{}$` renders as that literal string rather than vanishing - so a typo in one formula never blanks a paragraph.

## Styling {#styling}

The product adds two elements to the theme builder, usable wherever the base ones are:

```swift
EnrichedMarkdownText(content)
  .markdownLaTeX()
  .markdownTheme {
    MathBlock()
      .font(size: 22)
      .background(Color(.secondarySystemBackground))
      .padding(16)
      .marginBottom(24)
      .multilineTextAlignment(.leading)

    InlineMath()
      .foregroundStyle(.tint)
  }
```

### `MathBlock()`

Display math (`$$…$$`). Takes `.font(size:)`, `.foregroundStyle(_:)`, `.background(_:)` / `.backgroundStyle(_:)`, `.padding(_:)`, `.marginTop(_:)`, `.marginBottom(_:)`, and `.multilineTextAlignment(_:)` - **only** those. The typeface is always KaTeX's; there is no `.font(_:)` or `.font(custom:size:)`.

| Property | Default |
| --- | --- |
| Font size | `20` |
| Background | `.quaternary` |
| Padding | `12` |
| Margin bottom | `16` |
| Text alignment | `.center` |
| Color | follows the paragraph |

### `InlineMath()`

Inline math (`$…$`). Takes `.foregroundStyle(_:)` and nothing else - the size follows the surrounding text, which is what keeps a formula in a heading heading-sized.

### Where the math defaults sit in the stack

`.markdownLaTeX()` inserts `MarkdownTheme.latexDefault` directly **above** `MarkdownTheme.default` and **below** every theme you apply. So the table above is a floor, not a ceiling: your own `MathBlock()` overrides win whether you applied them on an ancestor or on the view itself, and you never have to re-state the defaults you did not want to change.

## Accessibility {#accessibility}

VoiceOver reads a formula as an English rendering of the source - "x squared over 2", "integral from 0 to 1 of …" - rather than spelling out LaTeX. The label is a parameter of the modifier, not of [`.markdownAccessibilityLabels`](/ios/api-reference/enriched-markdown-text#markdownaccessibilitylabels), because the math module owns it:

```swift
EnrichedMarkdownText(content)
  .markdownLaTeX(accessibilityLabel: "Formel: {speech}")
```

- **`{speech}`** is replaced by the spoken form. The default template is `"Math: {speech}"`.
- **`{latex}`** is replaced by the raw source instead, for apps that would rather read the markup.

The built-in conversion (`LaTeXSpeech.spokenForm(of:)`, which is public) is **English** and covers fractions, roots, powers and indices, sums, products, integrals and limits with their bounds, Greek letters, common relations and functions, decorations, and `\text`. A command it does not know is read by name. To localize a formula, or to plug in your own converter, pass a closure instead of a template:

```swift
EnrichedMarkdownText(content)
  .markdownLaTeX { latex in myLocalizedSpeech(for: latex) }
```

The closure receives the raw source and runs on the render queue, so keep it cheap and free of main-thread work.

## Rendering without a view {#rendering-without-a-view}

`MarkdownRenderer.renderLaTeX` mirrors [`MarkdownRenderer.render`](/ios/api-reference/markdown-theme#markdownrenderer) with math installed:

```swift
let config = MarkdownStyleConfiguration.resolve(
  layers: [.default, .latexDefault, myTheme],
  traitCollection: .current
)

let text = MarkdownRenderer.renderLaTeX(content, config: config)
```

:::caution
Resolving the config yourself means **you** place the `.latexDefault` layer. `MarkdownStyleConfiguration.baseline()` is `.default` alone, so a config built that way leaves `MathBlock` unstyled - no panel, no padding, no centering. Include `.latexDefault` between `.default` and your own layers, exactly as `.markdownLaTeX()` does.
:::

The same caveat as `render` applies: the returned attributed string carries the typeset formulas, but the decorations `EnrichedMarkdownText` draws around the text are not in it - see [UIKit interop](/ios/guides/uikit-interop).

## See also

- [LaTeX math](/rich-text-formatting/latex-math) - the feature at large, including which syntax is supported.
- [Style properties](/ios/api-reference/style-properties) - the base theme elements.
