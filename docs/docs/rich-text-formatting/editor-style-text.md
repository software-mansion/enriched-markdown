---
sidebar_label: Editor-style text
sidebar_position: 5
---

# Editor-style text

`EnrichedMarkdownText` normalizes whitespace the way CommonMark does: single newlines collapse into spaces, and runs of blank lines collapse into a single paragraph break. That is the right default for prose, but it means the rendered output does not match the raw line layout the user typed.

When you display content authored in [`EnrichedMarkdownTextInput`](/react-native/api-reference/enriched-markdown-text-input) - or any chat-style app where each Enter press should show up as its own line - you usually want the reverse: the output should reproduce the source line for line. Two [`md4cFlags`](/react-native/api-reference/enriched-markdown-text#md4cflags) plus a small style tweak get you there.

## Single newlines to line breaks

In the editor, pressing Enter once produces a single newline (a soft break). By default `EnrichedMarkdownText` collapses that to a space, flowing the two lines together. Enable [`hardSoftBreaks`](/react-native/api-reference/enriched-markdown-text#hardsoftbreaks) to render each soft break as a visible line break instead:

```tsx
<EnrichedMarkdownText
  markdown={markdownFromInput}
  md4cFlags={{ hardSoftBreaks: true }}
/>
```

## Blank lines to empty lines

Pressing Enter several times produces a run of blank lines. CommonMark collapses any such run into a single paragraph break, so three empty lines render the same as one. Enable [`preserveBlankLines`](/react-native/api-reference/enriched-markdown-text#preserveblanklines) to keep every blank line - each one renders as a single empty line, so the output keeps the exact number of blank lines that were typed:

```tsx
<EnrichedMarkdownText
  markdown={markdownFromInput}
  md4cFlags={{ preserveBlankLines: true }}
/>
```

## Zero the paragraph margins

Paragraph margins stack on top of the blank-line spacing. If you leave the default `paragraph` margins in place, a normal single-blank-line break already carries extra height, and blank lines add even more on top. Set `paragraph.marginTop` and `paragraph.marginBottom` to `0` so that vertical spacing is driven purely by the blank lines in the source:

```tsx
<EnrichedMarkdownText
  markdown={markdownFromInput}
  markdownStyle={{ paragraph: { marginTop: 0, marginBottom: 0 } }}
/>
```

## Putting it together

Combine both flags with zeroed paragraph margins to reproduce editor content line for line:

```tsx
<EnrichedMarkdownText
  markdown={markdownFromInput}
  markdownStyle={{ paragraph: { marginTop: 0, marginBottom: 0 } }}
  md4cFlags={{ hardSoftBreaks: true, preserveBlankLines: true }}
/>
```

With this configuration, every newline and every blank line the user typed in `EnrichedMarkdownTextInput` is rendered verbatim by `EnrichedMarkdownText` - the round trip preserves the exact line layout, which is what chat-style and note-taking apps expect.

:::note
Both flags apply only to the read-only `EnrichedMarkdownText` renderer; they describe how it parses an existing Markdown string. The editor itself always serializes newlines as it types.
:::

## See also

- [`md4cFlags`](/react-native/api-reference/enriched-markdown-text#md4cflags) - the full flag reference, with a live playground for each flag.
- [Line breaks](/react-native/api-reference/element-structure#line-breaks) and [Blank lines](/react-native/api-reference/element-structure#blank-lines) - the underlying newline and blank-line behavior.
