---
sidebar_label: RTL support
sidebar_position: 2
---

# RTL support

`EnrichedMarkdownText` resolves writing direction **per paragraph** on both platforms: each paragraph picks its own base direction from its first strong directional character. Arabic, Hebrew, and Persian content right-aligns automatically, even inside an LTR app and even when mixed with English paragraphs in the same document.

The editor (`EnrichedMarkdownTextInput`) follows the same per-paragraph rules; see its reference for input-specific caveats (placeholder, code blocks).

## No setup required

Every target resolves direction without configuration, by a different mechanism.

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
| **Tables** (`flavor="github"`) | On iOS, each cell resolves its own direction from its content. **On Android, cells are pinned to the device locale** (`TEXT_DIRECTION_LOCALE`), and column order and alignment follow the view direction - so an Arabic cell in an English-locale app lays out LTR. |
| **Code blocks** | Always LTR on iOS, and on Android under `flavor="github"` (the container pins it). Under `flavor="commonmark"` Android has no pin, so a code block whose first strong character is RTL takes an RTL base direction. |
| **Inline code** | Inherits its paragraph's direction on native; characters flow correctly via the platform Bidi algorithm. On **web** it is pinned `direction: ltr` with `unicode-bidi: embed`, so it does not inherit. |

## Neutral content

For paragraphs with no strong directional character (digits, punctuation), the direction falls back to the view's resolved layout direction. So `"123 456."` inside a `<View style={{ direction: 'rtl' }}>` right-aligns, and left-aligns otherwise - letting you place an LTR document in an RTL screen (or vice versa) without surprises.

## Copy-as-HTML caveat

When you copy content to the clipboard, the HTML representation carries at most a single `dir` attribute, and the two platforms derive it differently:

- **iOS and macOS** read it from the **document's first paragraph** (it can also be `"auto"`), and set it on `<html>`, or on `<table>` for a table copy.
- **Android** reads the **view's layout direction** instead, and only emits anything in the RTL case: `<html dir="rtl">` plus a wrapping `<div dir="rtl">`. An LTR copy gets a bare `<html>` with no `dir`, and a **table export carries no `dir` at all**.

Receivers (Gmail, Notes, Word) then apply their own Bidi algorithm to the pasted HTML, so a mixed-direction document will not reproduce the exact per-paragraph layout you see in-app - HTML's `dir` is scoped to elements, not to paragraphs within them. The plain-text and Markdown clipboard representations are unaffected and round-trip cleanly.

## Reference

- [`writingDirection`](/react-native/api-reference/enriched-markdown-text#writingdirection) - iOS base-direction mode (`'first-strong'` default). Android ignores it; it is stripped on web.
- [`dir`](/react-native/api-reference/enriched-markdown-text#dir) - base direction on web.
- Editor equivalent: [`EnrichedMarkdownTextInput`](/react-native/api-reference/enriched-markdown-text-input#writingdirection).

{/* UNRELEASED PLATFORMS: the standalone SDK tabs that lived here were stale and
must not be restored verbatim. Current truth: the iOS SDK has a full public
`MarkdownWritingDirection` enum plus a `markdownWritingDirection(_:)` modifier
defaulting to `.firstStrong`, implements first-strong itself, and already
mirrors decorations per paragraph. The Android SDK has no prop but does resolve
per paragraph and mirrors markers, numbers, checkboxes and blockquote bars; its
real exceptions are the blockquote box background fill, all table mirroring, and
the HTML clipboard export. */}
