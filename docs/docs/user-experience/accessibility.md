---
sidebar_label: Accessibility
sidebar_position: 1
---

# Accessibility

The library ships native accessibility support so screen readers (VoiceOver on iOS and TalkBack on Android) can navigate and announce Markdown content, with semantic labeling, custom navigation controls, and proper announcements for every supported element.

## How content is announced

Plain paragraphs without inline links or images are announced as a single element per paragraph. Paragraphs containing links or images are split into text, link, and image parts so each stays independently navigable. List items follow the same logic. Whitespace-only segments are filtered out to avoid empty announcements.

Broadly, only actionable content (links, images) creates separate segments. Inline formatting - bold, italic, underline, strikethrough, inline code, spoiler - is deliberately **not** split into its own accessibility element; the paragraph is read as one element, matching how screen readers already ignore visual emphasis.

## Translating announcements

The strings the screen reader speaks around your content (list announcements, blockquote suffix, table rows, math prefix, and the iOS rotor names) are overridable through the `accessibilityLabels` prop. Defaults are English; wire in your own i18n pipeline. Every field is optional - omit one and it keeps its English default.

Two strings are **not** covered: on Android the `"link"` and `"image"` role descriptions are hardcoded English with no label key.

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

The package also exports the defaults themselves - `DEFAULT_ACCESSIBILITY_LABELS`, the full English object, and `resolveAccessibilityLabels(partial)`, which merges your overrides onto it. `DEFAULT_ACCESSIBILITY_LABELS` is the natural thing to seed a translation table from.

{/* UNRELEASED PLATFORMS: the standalone iOS SDK takes a
`MarkdownAccessibilityLabels` value via `.markdownAccessibilityLabels(_:)`,
with a `list.top` / `list.nested` split instead of `nested*` field names, extra
`checkedTask` / `uncheckedTask` entries, an `image.fallback` and a
`codeBlock.copy` entry, and no `math` field (the formula label is a parameter
of `.markdownLaTeX`, speaking an English rendering by default). The standalone
Android SDK has no label-injection API at any layer and ships no strings.xml,
so its English literals cannot be localized at all. Restore those tabs when the
packages ship. */}

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
| **List items**  | "Bullet point" / "List item N" added as the element's accessibility value               | Same string set as the element's `roleDescription`, which replaces the role |
| **Blockquotes** | "Blockquote" / "Nested blockquote" added as the accessibility value                     | Same string set as `roleDescription`                                       |
| **Table rows**  | One focusable element per row, `"Row N: <cells>"`; header row carries the heading trait | One focusable overlay per row, same template; header row marked as heading |
| **Math**        | `"Math: <latex>"` (LaTeX read verbatim)                                                 | Same                                                                       |

A few element specifics:

- **Headings** announce the text followed by "heading". The **level is dropped entirely** - it is neither spoken nor exposed to platform navigation controls, so VoiceOver's rotor and TalkBack's reading controls jump between headings without distinguishing an H1 from an H4.
- **Images** with alt text announce it plus "image". An image **without** alt text behaves differently per platform: Android drops the element entirely, while iOS still creates a focusable, unlabeled element, so VoiceOver stops on it, says "image", and lists it in the Images rotor. Supply alt text in the Markdown either way.
- **Math** is read as raw LaTeX; the library does not convert it to natural language. Plug in a LaTeX-to-speech step on the consumer side if you need spoken math.

On iOS, VoiceOver also exposes custom **rotors** for headings, links, and images (a two-finger twist cycles rotors; swipe up/down jumps between elements of that type).

## Editor accessibility

The editor's model is intentionally simpler than the renderer's:

- **iOS (VoiceOver):** the field is a single accessibility element whose spoken value is the full plain text (delimiters stripped); when empty, the placeholder is announced. `accessibilityLabel` / `accessibilityHint` are forwarded. Double-tap activates the field for editing. It is not announced with the native "text field" role, and has no in-field cursor navigation or per-character echo - exposing the inner text view would be unreliable under the custom TextKit stack.
- **Android (TalkBack):** the input is a native `EditText`, announced and edited as a standard editable field.

## Font scaling

Text scaling is an accessibility setting too, and the renderer honors it by default on iOS and Android: [`allowFontScaling`](/react-native/api-reference/enriched-markdown-text#allowfontscaling) is `true`, so every size in `markdownStyle` scales with the OS **Text Size** setting, and [`maxFontSizeMultiplier`](/react-native/api-reference/enriched-markdown-text#maxfontsizemultiplier) caps how far it goes (`undefined` or `0` means no cap).

:::caution
Neither prop applies on web - both are stripped, and the web renderer emits absolute pixel sizes. A browser's minimum-font-size preference therefore has no effect on rendered Markdown; only page zoom does. If your web surface must respect a reader's text-size preference, drive `markdownStyle` sizes from your own CSS scale.
:::

## Accessibility on web

The web renderer is semantic HTML, so screen readers get real structure with no configuration: `<h1>`-`<h6>`, `<a>`, `<img alt>`, `<blockquote>`, `<ul>`/`<ol>`, a full `<table>`, `<pre><code>`, and a real `<input type="checkbox">` for task items. None of the native plumbing on this page applies - `accessibilityLabels` is stripped, the labels web emits are hard-coded English, and there is no rotor.

Four sharp edges are worth knowing:

- Setting `onCodeBlockPress` or `onImagePress` puts `role="button"` on the `<pre>` or `<img>`, which **replaces** their code and image semantics.
- Table header cells have no `scope` attribute.
- The horizontally scrollable table and code wrappers are not focusable and carry no `role="region"`, so a keyboard user cannot scroll them.
- `role="math"` with `aria-label={latex}` overrides the MathML KaTeX generates, so screen readers read the **raw LaTeX** rather than the structured equation.

## Known limitations

- **macOS** screen-reader support is still pending (a no-op stub ships today); see [macOS support](/react-native/guides/macos).
- **Android** has no rotor concept, so `accessibilityLabels.rotor.*` is ignored there.
- **Task list items** have no accessibility handling in the React Native package on either platform: a checkbox is read as plain list text, with no checked state announced and no toggle action exposed. There is no label key for it.
- **Admonitions** carry no accessibility role; they are announced as the blockquote they are built from.
- **Code blocks** are covered only partially - under `flavor="github"` the header copy button carries the resolved copy label, and iOS vends a VoiceOver copy action, but the block itself has no dedicated role.
- The platform tabs above describe the renderer. The **editor** speaks neither heading level nor task state (see [Editor accessibility](#editor-accessibility)).

## Reference

- [`accessibilityLabels`](/react-native/api-reference/enriched-markdown-text#accessibilitylabels) - translate every spoken string (see the Defaults table above).
- `DEFAULT_ACCESSIBILITY_LABELS` and `resolveAccessibilityLabels()` - the English defaults as a runtime value, and the merge helper, both exported from the package root.
- [`allowFontScaling` / `maxFontSizeMultiplier`](/react-native/api-reference/enriched-markdown-text#allowfontscaling) - see [Font scaling](#font-scaling) above.

{/* UNRELEASED PLATFORMS: iOS `.markdownAccessibilityLabels` /
`.markdownLaTeX(accessibilityLabel:)`, and the Android "no equivalent yet"
note, lived here. */}
