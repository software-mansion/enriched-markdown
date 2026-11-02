---
sidebar_label: Editor-style text
sidebar_position: 5
---

import EditorTextSrc from '!!raw-loader!@site/src/examples/react-native/rich-text-formatting/editor-style-text/EditorText';

# Editor-style text

The display component normalizes whitespace the way CommonMark does: single newlines collapse into spaces, and runs of blank lines collapse into a single paragraph break. That is the right default for prose, but it means the rendered output does not match the raw line layout the user typed.

The editor is a [WYSIWYG](https://en.wikipedia.org/wiki/WYSIWYG) surface: the user sees formatted text as they type, and each Enter and blank line they add is captured in the Markdown it produces. The round trip is exact because the editor's serializer is line-preserving - it splits on `\n`, rejoins on `\n`, and never lets an inline delimiter cross a newline - so one Enter press is exactly one `\n` in the output. All that is left is to tell the renderer not to normalize it away.

Two parser flags do that, and a style tweak makes the result look right:

1. **Soft breaks to line breaks.** Pressing Enter once in the editor produces a single newline (a soft break), which normally collapses to a space. The `hardSoftBreaks` flag renders each soft break as a visible line break instead. Default: `false`.
2. **Blank lines to empty lines.** Pressing Enter several times produces a run of blank lines, which CommonMark collapses to a single break. The `preserveBlankLines` flag keeps every blank line - each renders as one empty line, so the output keeps the exact number of blank lines that were typed. Default: `false`.
3. **Zero the paragraph bottom margin.** Paragraph margins stack on top of blank-line spacing. `paragraph.marginTop` is already `0`; it is `marginBottom`, which defaults to `16`, that you need to zero so the blank lines alone drive the vertical rhythm.

<CodeTabs groupId="platform">
<Tab label="React Native">

```tsx
<EnrichedMarkdownText
  markdown={markdownFromEditor}
  md4cFlags={{ hardSoftBreaks: true, preserveBlankLines: true }}
  markdownStyle={{ paragraph: { marginTop: 0, marginBottom: 0 } }}
/>
```

</Tab>
<Tab label="iOS">

```swift
EnrichedMarkdownText(
  markdownFromEditor,
  options: MarkdownParsingOptions(hardSoftBreaks: true, preserveBlankLines: true)
)
.markdownTheme {
  Paragraph()
    .marginBottom(0)
}
```

The flags are fields of [`options`](/ios/api-reference/enriched-markdown-text#options); the margin is set on [`Paragraph()`](/ios/api-reference/style-properties#paragraph), whose top margin is already unset.

</Tab>
<Tab label="Android">

```kotlin
EnrichedMarkdownText(
  markdown = markdownFromEditor,
  options = MarkdownOptions(hardSoftBreaks = true, preserveBlankLines = true),
  style = MarkdownTheme.style.merge {
    paragraph {
      marginTop = 0.dp
      marginBottom = 0.dp
    }
  },
)
```

The flags are named arguments of [`MarkdownOptions`](/android/api-reference/enriched-markdown-text#options) - they are not its first two parameters, so pass them by name.

</Tab>
</CodeTabs>

:::note
`hardSoftBreaks` applies to **every** soft break, not just the ones the editor produced. Prose that was hand-wrapped at 80 columns somewhere else will stop reflowing and keep its original line endings.
:::

## Putting it together

Combine both flags with zeroed paragraph margins to reproduce editor content line for line:

<LivePreview src={EditorTextSrc} />

With this configuration, every newline and every blank line the user typed in the editor is rendered verbatim - the round trip preserves the exact line layout, which is what chat-style and note-taking apps expect. In the React Native package both flags work on iOS, Android **and web**; the standalone iOS and Android SDKs take the same two flags, as shown in the tabs above.

:::note
Both flags belong to the **read-only renderer**; they describe how it parses an existing Markdown string. [`EnrichedMarkdownTextInput`](/react-native/api-reference/enriched-markdown-text-input) has no `md4cFlags` prop at all - there is nothing to configure on the editing side, because its serializer already preserves the lines.
:::

## Reference

- [`md4cFlags`](/react-native/api-reference/enriched-markdown-text#md4cflags) - the full flag reference, with a live playground per flag.
- [Line breaks](/react-native/api-reference/element-structure#line-breaks) and [Blank lines](/react-native/api-reference/element-structure#blank-lines) - the underlying newline and blank-line behavior.
- [`markdownStyle.paragraph`](/react-native/api-reference/style-properties#paragraph-and-heading-specific-paragraph-h1-h6) - the margin defaults you are overriding.
- **iOS** - [`options`](/ios/api-reference/enriched-markdown-text#options) (`MarkdownParsingOptions`), the [line-break and blank-line options](/ios/api-reference/element-structure#line-breaks), [Parser extensions](/ios/guides/parser-extensions), and [`Paragraph()`](/ios/api-reference/style-properties#paragraph) margins.
- **Android** - [`options`](/android/api-reference/enriched-markdown-text#options) (`MarkdownOptions`), the [line-break and blank-line options](/android/api-reference/element-structure#line-breaks), [Parser extensions](/android/guides/parser-extensions#line-break-handling), and [`paragraph`](/android/api-reference/style-properties#block-styles-paragraph-h1-h6) margins.
