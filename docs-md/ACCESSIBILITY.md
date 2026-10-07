# Accessibility

`react-native-enriched-markdown` provides comprehensive accessibility support for screen readers on both iOS and Android platforms.

## Overview

The library implements native accessibility features that enable screen readers (VoiceOver on iOS and TalkBack on Android) to properly navigate and understand Markdown content. This includes semantic labeling, custom navigation controls, and proper announcements for all supported elements.

## Text Announcements

Plain text paragraphs without inline links or images are announced as a single VoiceOver element per paragraph. Paragraphs containing links or images are segmented into text, link, and image parts so that each remains independently navigable. List items follow the same logic — a list item without inline specials is a single element, while one containing a link is split accordingly. Whitespace-only segments between elements are filtered out to avoid empty announcements.

## Translating announcements — `accessibilityLabels`

All strings spoken by the screen reader (list announcements, blockquote suffix, table rows, math equation prefix, and iOS rotor names) can be overridden via the optional `accessibilityLabels` prop on `EnrichedMarkdownText`. The defaults are English; consumers wire in their own i18n pipeline.

```tsx
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

<EnrichedMarkdownText
  markdown={markdown}
  accessibilityLabels={{
    list: {
      bulletPoint: 'Punkt',
      nestedBulletPoint: 'Eingebetteter Punkt',
      orderedItem: 'Listenelement {n}',
      nestedOrderedItem: 'Eingebettetes Listenelement {n}',
    },
    blockquote: {
      quote: 'Zitat',
      nestedQuote: 'Eingebettetes Zitat',
    },
    table: { row: 'Zeile {n}: {content}' },
    math: { equation: 'Formel: {latex}' },
    rotor: {
      headings: 'Überschriften',
      links: 'Links',
      images: 'Bilder',
    },
  }}
/>
```

Every field is optional. Any field you omit falls back to the English default below. Defaults are resolved on the JS side before being forwarded to native, so once you set even a single override the rest stay on their built-ins automatically.

### Defaults

| Field | Default | Platform |
|---|---|---|
| `list.bulletPoint` | `"Bullet point"` | iOS + Android |
| `list.nestedBulletPoint` | `"Nested bullet point"` | iOS + Android |
| `list.orderedItem` | `"List item {n}"` | iOS + Android |
| `list.nestedOrderedItem` | `"Nested list item {n}"` | iOS + Android |
| `blockquote.quote` | `"Blockquote"` | iOS + Android |
| `blockquote.nestedQuote` | `"Nested blockquote"` | iOS + Android |
| `table.row` | `"Row {n}: {content}"` | iOS + Android |
| `math.equation` | `"Math: {latex}"` | iOS + Android |
| `rotor.headings` | `"Headings"` | iOS only |
| `rotor.links` | `"Links"` | iOS only |
| `rotor.images` | `"Images"` | iOS only |

### Placeholder syntax

- `{n}` — 1-based index (list item number, table row index). Substituted at speak time.
- `{content}` — comma-joined cell texts for a table row.
- `{latex}` — math equation source.

Placeholder names must be preserved in translations exactly. Defaults intentionally use the no-plural cardinal form (`"List item 2"`, `"Row 2"`) instead of ordinals or count-aware variants — a single template works in every language without per-locale plural rules.

## Supported Elements

| Element | VoiceOver (iOS) | TalkBack (Android) |
|---------|-----------------|---------------------|
| **Headings (h1-h6)** | Rotor navigation, `UIAccessibilityTraitHeader` → "heading" suffix | Reading controls navigation, `isHeading = true` → "heading" suffix |
| **Links** | Rotor navigation, activatable, "link" suffix | Reading controls navigation, activatable, "link" suffix |
| **Images** | Alt text announced, rotor navigation, "image" suffix | Alt text announced, "image" role |
| **Unordered list items** | "Bullet point" / "Nested bullet point" appended (`accessibilityValue`) | Same string appended via `roleDescription` |
| **Ordered list items** | "List item N" / "Nested list item N" appended | Same string appended via `roleDescription` |
| **Blockquote content** | "Blockquote" / "Nested blockquote" appended | Same string appended via `roleDescription` |
| **Table rows** | One focusable element per row, `"Row N: <cells>"` label, header row carries `UIAccessibilityTraitHeader` | One focusable overlay per row, same template, header row carries `setAccessibilityHeading(true)` |
| **Math equations** | `"Math: <latex>"` (latex read verbatim — no TTS engine) | Same |

## Architecture

### iOS (VoiceOver)

**Custom Rotors:**
- **Headings Rotor**: Navigate between all headings in the document
- **Links Rotor**: Jump between all links
- **Images Rotor**: Navigate through all images

Rotor names are translated via `accessibilityLabels.rotor.*`. When VoiceOver is active, a two-finger twist on the screen cycles through these rotors; swipe up/down jumps between elements of the currently-selected type.

**Semantic Traits:**
- Headings: `UIAccessibilityTraitHeader | UIAccessibilityTraitStaticText`
- Links: `UIAccessibilityTraitLink | UIAccessibilityTraitStaticText`
- Images: `UIAccessibilityTraitImage` (+ `UIAccessibilityTraitLink` if the image is linked)
- Plain text: `UIAccessibilityTraitStaticText`

List, blockquote and table row labels are exposed via `accessibilityValue` so VoiceOver speaks them after the main text.

### Android (TalkBack)

**Reading Controls:**
- Headings, links, and images are available in TalkBack's reading controls for quick navigation
- List items are properly announced with their position and type (ordered vs unordered)

**Accessibility Node Info:**
- Headings: `isHeading = true` — TalkBack speaks "heading" as the role
- Links: `isClickable = true` + `roleDescription = "link"`
- Images: alt text becomes `contentDescription`, `roleDescription = "image"`
- List items: `CollectionItemInfoCompat` is set so TalkBack also announces position-in-collection; the localized label is appended via `roleDescription`
- Blockquote content: localized label appended via `roleDescription` (combined with link/list role when nested)
- Table rows: one transparent overlay per row exposes the row's joined content via `contentDescription`; header rows additionally call `ViewCompat.setAccessibilityHeading(true)`
- Math: `MathContainerView` exposes the full equation via `contentDescription` (`"Math: <latex>"` template)

## Element Details

### Headings

Headings are marked with the platform's "heading" trait/role. Screen readers announce the heading text followed by "heading" — the heading **level** is not spoken by default (the trait already conveys "this is a heading"; spelling the level out adds friction). The level remains available programmatically so platform navigation controls (rotor on iOS, reading controls on Android) can jump between headings of any level.

**Example announcement:**
- "Welcome to Markdown, heading"
- "Getting Started, heading"

### Links

Links are fully interactive and can be activated through screen reader gestures. The link text is announced followed by "link".

**Example announcement:**
- "React Native, link"

### Images

Images with alt text announce the alt text + "image". Images without alt text are intentionally **silent** (no fallback string) — if you want them announced, supply alt text in the markdown source.

**Example announcement:**
- "Misty forest at sunrise, image"
- *(silent for `![](url)`)*

### Lists

List items are announced with their position and type:

- Unordered: `"<text>, Bullet point"` (top-level) or `"<text>, Nested bullet point"` (deeper)
- Ordered: `"<text>, List item 1"`, `"<text>, List item 2"`, etc.

Override via `accessibilityLabels.list.*`. The `{n}` placeholder is substituted with the 1-based item number.

### Blockquotes

Content inside a blockquote gets the blockquote label appended (after any list or link suffix). Nested blockquotes use the `nestedQuote` label instead.

**Example announcement:**
- `"This is a quoted line., Blockquote"`
- `"Nested quote text., Nested blockquote"`

### Tables

Tables expose one focusable element per row (header included), labeled with the `table.row` template. The default reads `"Row 1: Column A, Column B"` for the header, `"Row 2: Cell A1, Cell B1"` for the first body row, and so on. The header row additionally carries the heading trait/role.

### Math

Each math block exposes a single focusable element labeled `"Math: <latex>"`. The library does **not** convert LaTeX to natural language — the screen reader reads the raw LaTeX source. If you need spoken math, plug in a LaTeX→speech library on the consumer side and translate the labels accordingly.

## Text input (`EnrichedMarkdownTextInput`)

The editor's accessibility model is intentionally simpler than the renderer's. The input is built on a custom TextKit stack, so its inner `UITextView` is not surfaced to VoiceOver directly — instead the component is presented as a **single accessibility element** that reads its whole content as one paragraph.

**iOS (VoiceOver):**
- The field is one element whose spoken value is the full plain text (delimiters stripped). When the field is empty, the placeholder is announced instead.
- `accessibilityLabel` / `accessibilityHint` set on the component are forwarded and announced.
- Double-tapping activates the field: it becomes first responder and the keyboard opens for editing.

**Android (TalkBack):** the input is a native `EditText`, announced and edited as a standard editable text field.

## Known Limitations

- **Inline formatting** (bold / italic / underline / strikethrough / inline code / spoiler) is not split into separate accessibility elements — the entire paragraph is read as one element, exactly as the surrounding text. Screen readers don't apply visual emphasis to bold/italic by default.
- **macOS** screen-reader support is still pending — `MarkdownAccessibilityElementBuilder.m` ships a no-op stub for macOS. Tracked as a TODO; iOS implementation can serve as a reference.
- **Android** has no rotor concept — `accessibilityLabels.rotor.*` is silently ignored on that platform.
- **iOS** blockquote backgrounds may break at link boundaries instead of spanning the full line. Visual only; doesn't affect accessibility.
- **Text input** (`EnrichedMarkdownTextInput`, iOS) is exposed as a single VoiceOver element reading its full plain text as one paragraph. It is **not** announced with the native "text field" role, has no in-field cursor navigation or per-character echo (editing happens via the keyboard after a double-tap activation), and its spoken value refreshes on re-focus rather than live. Exposing the inner `UITextView` for these would be unreliable under the custom TextKit stack (duplicate/flaky announcements). Inline formatting and headings are read as plain text.
