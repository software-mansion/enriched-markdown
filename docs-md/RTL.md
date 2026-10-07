# RTL Support

`react-native-enriched-markdown` resolves writing direction **per paragraph** on both platforms: each paragraph picks its own base direction from its first strong directional character. Arabic, Hebrew, and Persian content right-aligns automatically, even inside an LTR app and even when mixed with English paragraphs in the same document.

This document describes the read-only [`EnrichedMarkdownText`](TEXT.md) renderer. The rich [`EnrichedMarkdownTextInput`](INPUT.md#rtl-support) follows the same per-paragraph rules — see its [RTL section](INPUT.md#rtl-support) for input-specific caveats (placeholder, code blocks, etc.).

## Platform Setup

No setup is required. Both platforms autodetect direction per paragraph out of the box.

### Android

Uses Android's `TEXT_DIRECTION_FIRST_STRONG` heuristic on every `StaticLayout`. Paragraphs with no strong character fall back to the view's resolved layout direction (inherits ancestor `<View style={{ direction: 'rtl' }}>` and `I18nManager.isRTL`).

### iOS

iOS TextKit's `NSWritingDirectionNatural` does **not** do per-paragraph first-strong — it follows the app's global UI layout direction. The library implements first-strong itself as a post-render pass, matching Android's behavior. The mode is controlled by the [`writingDirection`](#writingdirection-prop-ios) prop and defaults to `'first-strong'`.

> **Note:** Earlier versions documented `I18nManager.forceRTL(true)` as a requirement on iOS. That is no longer needed for content direction — `first-strong` resolves each paragraph from its content. `I18nManager.forceRTL` still affects the surrounding app layout (Yoga direction, navigation, etc.) and remains useful if you want the whole app in RTL mode, but it's no longer a precondition for Markdown to render right-aligned.

## `writingDirection` prop (iOS)

| Value | Behavior |
|---|---|
| `'first-strong'` (default) | Per-paragraph autodetection. Neutral-only paragraphs fall back to the view's resolved layout direction. Matches Android. |
| `'auto'` | React Native parity. TextKit follows the app's `userInterfaceLayoutDirection`; mixed-direction documents do not auto-resolve. |
| `'ltr'` | Forces LTR on every paragraph. |
| `'rtl'` | Forces RTL on every paragraph. |

Code blocks always render LTR regardless of this prop.

Android ignores the prop; it always uses first-strong via the platform.

```tsx
// Default — mixed Arabic/English document renders each paragraph correctly.
<EnrichedMarkdownText markdown={mixedContent} />

// Force RTL for the whole document (e.g. forms or admin UI in an Arabic locale).
<EnrichedMarkdownText writingDirection="rtl" markdown={content} />
```

## Element RTL Behavior

Each element follows the **paragraph it belongs to**, not a global flag — so a single document can mix sides cleanly.

| Element | Behavior |
|---|---|
| **Paragraphs & headings** | Base direction set per paragraph from first-strong (or forced by the prop). |
| **Unordered lists** | Bullet drawn on the side that matches the item's paragraph direction. |
| **Ordered lists** | Number drawn on the side that matches the item's paragraph direction. |
| **Task lists** | Checkbox drawn on the matching side; tap hit-test follows the same side. |
| **Blockquotes** | Border drawn on the side that matches the quoted paragraph. |
| **Tables** (`flavor="github"`) | Each cell resolves its own direction independently from cell content. |
| **Code blocks** | Always LTR. |
| **Inline code** | Inherits its paragraph's direction; characters flow correctly via TextKit Bidi. |

## Yoga layout-direction inheritance

For paragraphs with no strong directional character (digits, punctuation, block spacers), the library falls back to the view's **Yoga-resolved layout direction**. That means:

```tsx
// "123 456 789." has no strong character. Inside an RTL ancestor view,
// it right-aligns; otherwise it left-aligns.
<View style={{ direction: 'rtl' }}>
  <EnrichedMarkdownText markdown="123 456 789." />
</View>
```

This mirrors Android's first-strong fallback and lets you place an LTR app in an RTL screen (or vice versa) without surprises for neutral content.

## Copy-as-HTML caveat

When you copy markdown content to the clipboard, the HTML representation carries a single `dir` attribute on `<html>` (or on `<table>` for table copies). That attribute is read from the document's first paragraph:

- `first-strong` document starting with Arabic → `<html dir="rtl">`
- `first-strong` document starting with English → `<html dir="ltr">`
- `'auto'` → `<html dir="auto">` (receivers do best-effort first-strong)
- `'ltr'` / `'rtl'` → forced

**Receivers (Gmail, Notes, Word, etc.) apply their own Bidi algorithm to the pasted HTML.** Mixed-direction documents may not visually reproduce the per-paragraph layout you see in-app — receivers can only honor what the markup encodes, and HTML's `dir` attribute is scoped to elements, not paragraphs within them. The plain-text and Markdown clipboard representations are unaffected and round-trip cleanly.

If you need precise mixed-direction output in a specific receiver, the rendered HTML carries no per-`<p>` `dir` attribute today — that would be a future enhancement.
