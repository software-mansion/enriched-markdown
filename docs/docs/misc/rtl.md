---
sidebar_label: RTL support
sidebar_position: 4
---

# RTL support

`EnrichedMarkdownText` resolves writing direction **per paragraph** on both platforms: each paragraph picks its own base direction from its first strong directional character. Arabic, Hebrew, and Persian content right-aligns automatically, even inside an LTR app and even when mixed with English paragraphs in the same document.

The editor (`EnrichedMarkdownTextInput`) follows the same per-paragraph rules; see its reference for input-specific caveats (placeholder, code blocks).

## No setup required

Both platforms autodetect direction per paragraph out of the box.

- **Android** uses the platform `TEXT_DIRECTION_FIRST_STRONG` heuristic on every layout. Paragraphs with no strong character fall back to the view's resolved layout direction (which inherits an ancestor `<View style={{ direction: 'rtl' }}>` and `I18nManager.isRTL`).
- **iOS** TextKit does not do per-paragraph first-strong on its own - it follows the app's global UI layout direction - so the library implements first-strong itself as a post-render pass, matching Android. The mode is controlled by the `writingDirection` prop and defaults to `'first-strong'`.
- **Web** uses CSS logical properties; set the base direction with the `dir` prop on the container.

:::note
Earlier versions documented `I18nManager.forceRTL(true)` as a requirement on iOS. That is no longer needed for content direction - `first-strong` resolves each paragraph from its content. `I18nManager.forceRTL` still affects the surrounding app layout and remains useful for a fully RTL app, but it is not a precondition for Markdown to render right-aligned.
:::

## Controlling direction

On iOS, the `writingDirection` prop selects how each paragraph's base direction is resolved:

| Value | Behavior |
|---|---|
| `'first-strong'` (default) | Per-paragraph autodetection; neutral-only paragraphs fall back to the view's resolved layout direction. Matches Android. |
| `'auto'` | React Native parity: TextKit follows the app's `userInterfaceLayoutDirection`; mixed-direction documents do not auto-resolve. |
| `'ltr'` | Forces LTR on every paragraph. |
| `'rtl'` | Forces RTL on every paragraph. |

Android ignores the prop (it always uses the platform first-strong heuristic); on web, use the `dir` prop instead. Code blocks always render LTR regardless.

## Element behavior

Each element follows the **paragraph it belongs to**, not a global flag, so a single document can mix sides cleanly:

| Element | Behavior |
|---|---|
| **Paragraphs and headings** | Base direction set per paragraph from first-strong (or forced by the prop). |
| **Unordered / ordered lists** | Bullet or number drawn on the side that matches the item's paragraph direction. |
| **Task lists** | Checkbox drawn on the matching side; the tap hit-test follows the same side. |
| **Blockquotes** | Accent bar drawn on the side that matches the quoted paragraph. |
| **Tables** (`flavor="github"`) | Each cell resolves its own direction independently from cell content. |
| **Code blocks** | Always LTR. |
| **Inline code** | Inherits its paragraph's direction; characters flow correctly via the platform Bidi algorithm. |

## Neutral content

For paragraphs with no strong directional character (digits, punctuation), the direction falls back to the view's resolved layout direction. So `"123 456."` inside a `<View style={{ direction: 'rtl' }}>` right-aligns, and left-aligns otherwise - letting you place an LTR document in an RTL screen (or vice versa) without surprises.

## Copy-as-HTML caveat

When you copy content to the clipboard, the HTML representation carries a single `dir` attribute on `<html>` (or on `<table>` for table copies), read from the document's first paragraph. Receivers (Gmail, Notes, Word) then apply their own Bidi algorithm to the pasted HTML, so a mixed-direction document may not reproduce the exact per-paragraph layout you see in-app - HTML's `dir` is scoped to elements, not paragraphs within them. The plain-text and Markdown clipboard representations are unaffected and round-trip cleanly.

## Reference

<CodeTabs groupId="platform">
<Tab label="React Native">

- [`writingDirection`](/react-native/api-reference/enriched-markdown-text#writingdirection) - iOS base-direction mode (`'first-strong'` default).
- [`dir`](/react-native/api-reference/enriched-markdown-text#dir) - base direction on web.
- Editor equivalent: [`EnrichedMarkdownTextInput`](/react-native/api-reference/enriched-markdown-text-input#writingdirection).

</Tab>
<Tab label="iOS"><ComingSoon platform="iOS" /></Tab>
<Tab label="Android"><ComingSoon platform="Android" /></Tab>
</CodeTabs>
