---
sidebar_label: RTL support
sidebar_position: 2
---

# RTL support

`EnrichedMarkdownText` resolves writing direction **per paragraph** on both platforms: each paragraph picks its own base direction from its first strong directional character. Arabic, Hebrew, and Persian content right-aligns automatically, even inside an LTR app and even when mixed with English paragraphs in the same document.

The React Native package's editor (`EnrichedMarkdownTextInput`) follows the same per-paragraph rules; see its reference for input-specific caveats (placeholder, code blocks).

## No setup required

Every package resolves direction without configuration.

<CodeTabs groupId="platform">
<Tab label="React Native">

In the React Native package, every target resolves direction without configuration, by a different mechanism.

- **Android** uses the platform `TEXT_DIRECTION_FIRST_STRONG` heuristic on every layout. Paragraphs with no strong character fall back to the view's resolved layout direction (which inherits an ancestor `<View style={{ direction: 'rtl' }}>` and `I18nManager.isRTL`).
- **iOS** TextKit does not do per-paragraph first-strong on its own - it follows the app's global UI layout direction - so the library implements first-strong itself as a post-render pass, matching Android. The mode is controlled by the `writingDirection` prop and defaults to `'first-strong'`.
- **Web** uses CSS logical properties, so blockquote borders and list indentation flip with the container's direction, which you set through the [`dir`](/react-native/api-reference/enriched-markdown-text#dir) prop.

:::caution
Web resolves direction **once, at the container level**. No renderer emits a per-element `dir` or `unicode-bidi`, so a mixed-direction document does **not** resolve per paragraph on web the way it does on native - the whole block takes the root's direction. [`writingDirection`](/react-native/api-reference/enriched-markdown-text#writingdirection) is stripped there; `dir` is the only control.

Two table properties are also physical rather than logical and do not flip: an unaligned column falls back to `text-align: left`, and the table wrapper uses physical `marginLeft`/`marginRight`.
:::

:::note
Earlier versions documented `I18nManager.forceRTL(true)` as a requirement on iOS. That is no longer needed for content direction - `first-strong` resolves each paragraph from its content. `I18nManager.forceRTL` still affects the surrounding app layout and remains useful for a fully RTL app, but it is not a precondition for Markdown to render right-aligned.
:::

</Tab>
<Tab label="iOS">

TextKit does not do per-paragraph first-strong on its own, so the standalone iOS SDK implements it itself: under the default [`.markdownWritingDirection(.firstStrong)`](/ios/api-reference/enriched-markdown-text#markdownwritingdirection), each paragraph takes its base direction from its first strong character. A paragraph with no strong character follows the SwiftUI `layoutDirection` environment value.

</Tab>
<Tab label="Android">

The standalone Android SDK resolves each paragraph from its first strong character, with no direction parameter to set.

</Tab>
</CodeTabs>

## Controlling direction

<CodeTabs groupId="platform">
<Tab label="React Native">

In the React Native package, the iOS `writingDirection` prop selects how each paragraph's base direction is resolved:

| Value | Behavior |
|---|---|
| `'first-strong'` (default) | Per-paragraph autodetection; neutral-only paragraphs fall back to the view's resolved layout direction. Matches Android. |
| `'auto'` | React Native parity: TextKit follows the app's `userInterfaceLayoutDirection`; mixed-direction documents do not auto-resolve. |
| `'ltr'` | Forces LTR on every paragraph. |
| `'rtl'` | Forces RTL on every paragraph. |

Android ignores the prop (it always uses the platform first-strong heuristic); on web, use the `dir` prop instead. Code blocks always render LTR regardless.

</Tab>
<Tab label="iOS">

The standalone iOS SDK takes a `MarkdownWritingDirection` through `.markdownWritingDirection(_:)`:

```swift
EnrichedMarkdownText(content)
  .markdownWritingDirection(.rightToLeft)
```

| Case | Behavior |
|---|---|
| `.firstStrong` (default) | Per-paragraph autodetection; a paragraph with no strong character follows the SwiftUI `layoutDirection`. |
| `.natural` | Direction is left to TextKit. Decorations, and paragraphs with no strong character, follow the app's interface direction. |
| `.leftToRight` | Forces left-to-right on every paragraph. |
| `.rightToLeft` | Forces right-to-left on every paragraph. |

Code blocks always render left-to-right, whichever case is set. See [`.markdownWritingDirection`](/ios/api-reference/enriched-markdown-text#markdownwritingdirection).

</Tab>
<Tab label="Android">

The standalone Android SDK has no direction parameter: every paragraph is always resolved from its first strong character.

</Tab>
</CodeTabs>

## Element behavior

<CodeTabs groupId="platform">
<Tab label="React Native">

Each element follows the **paragraph it belongs to**, not a global flag, so a single document can mix sides cleanly:

| Element | Behavior |
|---|---|
| **Paragraphs and headings** | Base direction set per paragraph from first-strong (or forced by the prop). |
| **Unordered / ordered lists** | Bullet or number drawn on the side that matches the item's paragraph direction. |
| **Task lists** | Checkbox drawn on the matching side; the tap hit-test follows the same side. |
| **Blockquotes** | Accent bar drawn on the side that matches the quoted paragraph. |
| **Tables** (`flavor="github"`) | On iOS, each cell resolves its own direction from its content. **On Android, cells are pinned to the device locale** (`TEXT_DIRECTION_LOCALE`), and column order and alignment follow the app's locale layout direction rather than the view's - so an Arabic cell in an English-locale app lays out LTR. |
| **Code blocks** | Always LTR on iOS, and on Android under `flavor="github"` (the container pins it). Under `flavor="commonmark"` Android has no pin, so a code block whose first strong character is RTL takes an RTL base direction. |
| **Inline code** | Inherits its paragraph's direction on native; characters flow correctly via the platform Bidi algorithm. On **web** it is pinned `direction: ltr` with `unicode-bidi: embed`, so it does not inherit. |

</Tab>
<Tab label="iOS">

Under every case other than `.natural`, each element follows the **paragraph it belongs to**, even in a left-to-right app:

| Element | Behavior |
|---|---|
| **Paragraphs and headings** | Base direction set per paragraph from first-strong (or forced by the modifier). |
| **Unordered / ordered lists** | Bullet or number drawn on the side that matches the item's paragraph direction. |
| **Task lists** | Checkbox drawn on the matching side. |
| **Blockquotes** | Accent bar drawn on the side that matches the quoted paragraph. |
| **Admonitions** | The title takes the direction of the body it introduces. |
| **Code blocks** | Always left-to-right. |

See [Writing direction](/ios/api-reference/element-structure#writing-direction).

</Tab>
<Tab label="Android">

| Element | Behavior |
|---|---|
| **Paragraphs and headings** | Base direction set per paragraph from first-strong. |
| **Unordered / ordered lists** | Bullet or number drawn on the side that matches the item's paragraph direction. |
| **Task lists** | Checkbox drawn on the matching side. |
| **Blockquotes** | Accent bar drawn on the side that matches the quoted paragraph. The box **background fill does not mirror**. |
| **Tables** | Mirror by the **device locale** (`Configuration.layoutDirection`), not per paragraph or per cell content; cells are pinned to `TEXT_DIRECTION_LOCALE`. An Arabic cell in an English-locale app lays out left-to-right. |
| **Code blocks** | **Not** pinned left-to-right: a code block takes first-strong like any paragraph, so one whose first strong character is RTL lays out right-to-left. |

</Tab>
</CodeTabs>

## Neutral content

In the React Native package, for paragraphs with no strong directional character (digits, punctuation), the direction falls back to the view's resolved layout direction. So `"123 456."` inside a `<View style={{ direction: 'rtl' }}>` right-aligns, and left-aligns otherwise - letting you place an LTR document in an RTL screen (or vice versa) without surprises. In the standalone iOS SDK, the fallback is the SwiftUI `layoutDirection` environment value.

## Copy-as-HTML caveat

When you copy content to the clipboard, the HTML representation carries at most a single `dir` attribute. In the React Native package, the two platforms derive it differently:

- **iOS and macOS** read it from the **document's first paragraph** (it can also be `"auto"`), and set it on `<html>`, or on `<table>` for a table copy.
- **Android** reads the **app's locale layout direction** (its resource configuration, not the view) instead, and only emits anything in the RTL case: `<html dir="rtl">` plus a wrapping `<div dir="rtl">`. An LTR copy gets a bare `<html>` with no `dir`, and a **table export carries no `dir` at all**.

Receivers (Gmail, Notes, Word) then apply their own Bidi algorithm to the pasted HTML, so a mixed-direction document will not reproduce the exact per-paragraph layout you see in-app - HTML's `dir` is scoped to elements, not to paragraphs within them. The plain-text and Markdown clipboard representations are unaffected and round-trip cleanly.

The standalone SDKs:

- **Android** takes the `dir` from the **device locale**, and a table export carries no `dir` at all.
- **iOS** copies a table from its long-press menu as plain text only, so no HTML `dir` applies there.

## Reference

<CodeTabs groupId="platform">
<Tab label="React Native">

- [`writingDirection`](/react-native/api-reference/enriched-markdown-text#writingdirection) - iOS base-direction mode (`'first-strong'` default). Android ignores it; it is stripped on web.
- [`dir`](/react-native/api-reference/enriched-markdown-text#dir) - base direction on web.
- Editor equivalent: [`EnrichedMarkdownTextInput`](/react-native/api-reference/enriched-markdown-text-input#writingdirection).

</Tab>
<Tab label="iOS">

- [`.markdownWritingDirection`](/ios/api-reference/enriched-markdown-text#markdownwritingdirection) - base-direction mode (`.firstStrong` default).
- [Writing direction](/ios/api-reference/element-structure#writing-direction) - how decorations and code blocks follow it.

</Tab>
<Tab label="Android">

- No direction parameter - paragraphs always resolve from their first strong character, and tables follow the device locale.

</Tab>
</CodeTabs>
