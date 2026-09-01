---
sidebar_label: Editor-style text
sidebar_position: 5
---

# Editor-style text

The display component normalizes whitespace the way CommonMark does: single newlines collapse into spaces, and runs of blank lines collapse into a single paragraph break. That is the right default for prose, but it means the rendered output does not match the raw line layout the user typed.

The editor is a [WYSIWYG](https://en.wikipedia.org/wiki/WYSIWYG) surface: the user sees formatted text as they type, and each Enter and blank line they add is captured in the Markdown it produces. When you display that content - or any chat-style app where each Enter press should show up as its own line - you usually want the output to reproduce the source line for line. Two parser flags plus a small style tweak get you there:

1. **Soft breaks to line breaks.** Pressing Enter once in the editor produces a single newline (a soft break), which normally collapses to a space. The `hardSoftBreaks` flag renders each soft break as a visible line break instead.
2. **Blank lines to empty lines.** Pressing Enter several times produces a run of blank lines, which CommonMark collapses to a single break. The `preserveBlankLines` flag keeps every blank line - each renders as one empty line, so the output keeps the exact number of blank lines that were typed.
3. **Zero the paragraph margins.** Paragraph margins stack on top of blank-line spacing, so with the flags on you usually set the paragraph's top and bottom margins to `0` and let the blank lines drive the vertical rhythm.

## Putting it together

Combine both flags with zeroed paragraph margins to reproduce editor content line for line:

<CodeTabs groupId="platform">
<Tab label="React Native">

```tsx
<EnrichedMarkdownText
  markdown={markdownFromInput}
  markdownStyle={{ paragraph: { marginTop: 0, marginBottom: 0 } }}
  md4cFlags={{ hardSoftBreaks: true, preserveBlankLines: true }}
/>
```

</Tab>
<Tab label="iOS"><ComingSoon platform="iOS" /></Tab>
<Tab label="Android"><ComingSoon platform="Android" /></Tab>
</CodeTabs>

With this configuration, every newline and every blank line the user typed in the editor is rendered verbatim - the round trip preserves the exact line layout, which is what chat-style and note-taking apps expect.

:::note
Both flags apply only to the read-only renderer; they describe how it parses an existing Markdown string. The editor itself always serializes newlines as it types.
:::

## Reference

<CodeTabs groupId="platform">
<Tab label="React Native">

- [`md4cFlags`](/react-native/api-reference/enriched-markdown-text#md4cflags) - the full flag reference, with a live playground per flag.
- [Line breaks](/react-native/api-reference/element-structure#line-breaks) and [Blank lines](/react-native/api-reference/element-structure#blank-lines) - the underlying newline and blank-line behavior.

</Tab>
<Tab label="iOS"><ComingSoon platform="iOS" /></Tab>
<Tab label="Android"><ComingSoon platform="Android" /></Tab>
</CodeTabs>
