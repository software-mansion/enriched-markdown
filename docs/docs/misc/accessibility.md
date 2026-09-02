---
sidebar_label: Accessibility
sidebar_position: 5
---

# Accessibility

The library ships native accessibility support so screen readers (VoiceOver on iOS and TalkBack on Android) can navigate and announce Markdown content, with semantic labeling, custom navigation controls, and proper announcements for every supported element.

## How content is announced

Plain paragraphs without inline links or images are announced as a single element per paragraph. Paragraphs containing links or images are split into text, link, and image parts so each stays independently navigable. List items follow the same logic. Whitespace-only segments are filtered out to avoid empty announcements.

Only actionable content (links, images) creates separate segments. Inline formatting - bold, italic, underline, strikethrough, inline code, spoiler - is deliberately **not** split into its own accessibility element; the paragraph is read as one element, matching how screen readers already ignore visual emphasis.

## Translating announcements

All strings spoken by the screen reader (list announcements, blockquote suffix, table rows, math prefix, and the iOS rotor names) can be overridden through the `accessibilityLabels` prop. Defaults are English; wire in your own i18n pipeline. Every field is optional - omit one and it keeps its English default.

<CodeTabs groupId="platform">
<Tab label="React Native">

```tsx
<EnrichedMarkdownText
  markdown={markdown}
  accessibilityLabels={{
    list: {
      bulletPoint: 'Punkt',
      nestedBulletPoint: 'Eingebetteter Punkt',
      orderedItem: 'Listenelement {n}',
      nestedOrderedItem: 'Eingebettetes Listenelement {n}',
    },
    blockquote: { quote: 'Zitat', nestedQuote: 'Eingebettetes Zitat' },
    table: { row: 'Zeile {n}: {content}' },
    math: { equation: 'Formel: {latex}' },
    rotor: { headings: 'Überschriften', links: 'Links', images: 'Bilder' },
  }}
/>
```

</Tab>
<Tab label="iOS"><ComingSoon platform="iOS" /></Tab>
<Tab label="Android"><ComingSoon platform="Android" /></Tab>
</CodeTabs>

### Defaults

| Field                                             | Default                               | Platform      |
| ------------------------------------------------- | ------------------------------------- | ------------- |
| `list.bulletPoint`                                | `"Bullet point"`                      | iOS + Android |
| `list.nestedBulletPoint`                          | `"Nested bullet point"`               | iOS + Android |
| `list.orderedItem`                                | `"List item {n}"`                     | iOS + Android |
| `list.nestedOrderedItem`                          | `"Nested list item {n}"`              | iOS + Android |
| `blockquote.quote`                                | `"Blockquote"`                        | iOS + Android |
| `blockquote.nestedQuote`                          | `"Nested blockquote"`                 | iOS + Android |
| `table.row`                                       | `"Row {n}: {content}"`                | iOS + Android |
| `math.equation`                                   | `"Math: {latex}"`                     | iOS + Android |
| `rotor.headings` / `rotor.links` / `rotor.images` | `"Headings"` / `"Links"` / `"Images"` | iOS only      |

Placeholders: `{n}` (1-based index), `{content}` (comma-joined cell texts), `{latex}` (equation source). Preserve placeholder names exactly in translations. Defaults use the no-plural cardinal form so a single template works in every language.

## Supported elements

| Element         | VoiceOver (iOS)                                                                         | TalkBack (Android)                                                         |
| --------------- | --------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| **Headings**    | Rotor navigation, "heading" suffix                                                      | Reading-controls navigation, "heading" suffix                              |
| **Links**       | Rotor navigation, activatable, "link" suffix                                            | Reading-controls navigation, activatable, "link" suffix                    |
| **Images**      | Alt text announced, rotor navigation, "image" suffix                                    | Alt text announced, "image" role                                           |
| **List items**  | "Bullet point" / "List item N" appended                                                 | Same string appended via `roleDescription`                                 |
| **Blockquotes** | "Blockquote" / "Nested blockquote" appended                                             | Same string appended via `roleDescription`                                 |
| **Table rows**  | One focusable element per row, `"Row N: <cells>"`; header row carries the heading trait | One focusable overlay per row, same template; header row marked as heading |
| **Math**        | `"Math: <latex>"` (LaTeX read verbatim)                                                 | Same                                                                       |

A few element specifics:

- **Headings** announce the text followed by "heading"; the level is not spoken (the trait already conveys it) but remains available to platform navigation controls (the iOS rotor, Android reading controls).
- **Images** with alt text announce it plus "image"; images without alt text are intentionally silent - supply alt text in the Markdown to have them announced.
- **Math** is read as raw LaTeX; the library does not convert it to natural language. Plug in a LaTeX-to-speech step on the consumer side if you need spoken math.

On iOS, VoiceOver also exposes custom **rotors** for headings, links, and images (a two-finger twist cycles rotors; swipe up/down jumps between elements of that type). Android has no rotor concept, so `accessibilityLabels.rotor.*` is ignored there.

## Editor accessibility

The editor's model is intentionally simpler than the renderer's:

- **iOS (VoiceOver):** the field is a single accessibility element whose spoken value is the full plain text (delimiters stripped); when empty, the placeholder is announced. `accessibilityLabel` / `accessibilityHint` are forwarded. Double-tap activates the field for editing. It is not announced with the native "text field" role, and has no in-field cursor navigation or per-character echo - exposing the inner text view would be unreliable under the custom TextKit stack.
- **Android (TalkBack):** the input is a native `EditText`, announced and edited as a standard editable field.

## Known limitations

- **macOS** screen-reader support is still pending (a no-op stub ships today); see [macOS support](/misc/macos).
- **Android** has no rotor concept, so `accessibilityLabels.rotor.*` is ignored there.

## Reference

<CodeTabs groupId="platform">
<Tab label="React Native">

- [`accessibilityLabels`](/react-native/api-reference/enriched-markdown-text#accessibilitylabels) - translate every spoken string (see the Defaults table above).

</Tab>
<Tab label="iOS"><ComingSoon platform="iOS" /></Tab>
<Tab label="Android"><ComingSoon platform="Android" /></Tab>
</CodeTabs>
