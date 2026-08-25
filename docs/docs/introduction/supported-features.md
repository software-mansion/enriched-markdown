---
sidebar_label: Feature support
sidebar_position: 3
---

# Feature support

:::caution
THIS PAGE IS WORK IN PROGRESS

scaffold - the support cells below (especially the entire
`enrichedmarkdowntextinput` section) are provisional and need verifying against
each library's actual capabilities before launch.
:::

Which features are implemented in each **library** - native iOS, native
Android, and React Native - organized by component and by how the feature is
enabled. The React Native column is tracked separately because a feature can
exist in a native SDK before it is surfaced in the React Native wrapper. The
**Web** column covers React Native for Web (via
[`react-native-web`](https://necolas.github.io/react-native-web/)) and applies
only to `EnrichedMarkdownText` - the editor is native-only. For the syntax
itself see [Core concepts](/introduction/core-concepts); for per-element detail
and style properties see each platform's **Element structure** reference.

## EnrichedMarkdownText

The display component - parses a Markdown string and renders it. Runs on iOS,
Android, React Native, and the web - see the [Web support](/react-native/guides/web-support)
guide for web specifics.

### CommonMark

Available by default, no configuration required.

| Feature                     | iOS | Android | React Native | Web |
| --------------------------- | :-: | :-----: | :----------: | :-: |
| Headings                    | Yes |   Yes   |     Yes      | Yes |
| Paragraphs                  | Yes |   Yes   |     Yes      | Yes |
| Bold / italic               | Yes |   Yes   |     Yes      | Yes |
| Inline code                 | Yes |   Yes   |     Yes      | Yes |
| Links                       | Yes |   Yes   |     Yes      | Yes |
| Lists (ordered / unordered) | Yes |   Yes   |     Yes      | Yes |
| Blockquotes                 | Yes |   Yes   |     Yes      | Yes |
| Code blocks                 | Yes |   Yes   |     Yes      | Yes |
| Thematic break              | Yes |   Yes   |     Yes      | Yes |
| Images                      | Yes |   Yes   |     Yes      | Yes |

### GitHub Flavored Markdown

Enabled with `flavor="github"` on native. See [Markdown flavors](/rich-text-formatting/markdown-flavors).

:::note
The web renderer has no `flavor` prop - tables, task lists and strikethrough are
always enabled. The exception is bare-URL autolinking, which the web WASM entry
point does not expose, so it cannot be turned on there.
:::

| Feature         | iOS | Android | React Native | Web |
| --------------- | :-: | :-----: | :----------: | :-: |
| Tables          | Yes |   Yes   |     Yes      | Yes |
| Task lists      | Yes |   Yes   |     Yes      | Yes |
| Strikethrough   | Yes |   Yes   |     Yes      | Yes |
| Autolinked URLs | Yes |   Yes   |     Yes      | No  |

### Inline extensions

Toggled independently through the `md4cFlags` prop, not the flavor.

| Feature                | iOS | Android |  React Native  | Web  |
| ---------------------- | :-: | :-----: | :------------: | :--: |
| Underline (`_text_`)   | Yes |   No    | Yes (iOS only) | Yes  |
| Strikethrough color    | Yes |   No    | Yes (iOS only) | TODO |
| Superscript (`^text^`) | Yes |   Yes   |      Yes       | Yes  |
| Subscript (`~text~`)   | Yes |   Yes   |      Yes       | Yes  |
| Highlight (`==text==`) | Yes |   Yes   |      Yes       | Yes  |

### Advanced features

Each has its own page under **Rich text formatting**.

| Feature                 | iOS | Android | React Native | Web  | Learn more                                                         |
| ----------------------- | :-: | :-----: | :----------: | :--: | ------------------------------------------------------------------ |
| LaTeX math              | Yes |   Yes   |     Yes      | Yes  | [LaTeX math](/rich-text-formatting/latex-math)                     |
| Mentions                | Yes |   Yes   |     Yes      | TODO | [Mentions](/rich-text-formatting/mentions)                         |
| Code-block highlighting | Yes |   Yes   |     Yes      | TODO | [Code-block highlighting](/rich-text-formatting/code-highlighting) |
| Markdown streaming      | Yes |   Yes   |     Yes      |  No  | [Markdown streaming](/rich-text-formatting/markdown-streaming)     |

## EnrichedMarkdownTextInput

The editor - produces a Markdown string as the user types. **Native-only**: not
available on web.

### CommonMark

| Feature                     | iOS  | Android | React Native |
| --------------------------- | :--: | :-----: | :----------: |
| Headings                    | TODO |  TODO   |     TODO     |
| Bold / italic               | TODO |  TODO   |     TODO     |
| Inline code                 | TODO |  TODO   |     TODO     |
| Links                       | TODO |  TODO   |     TODO     |
| Lists (ordered / unordered) | TODO |  TODO   |     TODO     |
| Blockquotes                 | TODO |  TODO   |     TODO     |
| Code blocks                 | TODO |  TODO   |     TODO     |

### GitHub Flavored Markdown

| Feature       | iOS  | Android | React Native |
| ------------- | :--: | :-----: | :----------: |
| Tables        | TODO |  TODO   |     TODO     |
| Task lists    | TODO |  TODO   |     TODO     |
| Strikethrough | TODO |  TODO   |     TODO     |

### Inline extensions

| Feature                 | iOS  | Android | React Native |
| ----------------------- | :--: | :-----: | :----------: |
| Underline               | TODO |  TODO   |     TODO     |
| Superscript / subscript | TODO |  TODO   |     TODO     |
| Highlight               | TODO |  TODO   |     TODO     |

### Advanced features

| Feature  | iOS  | Android | React Native | Learn more                                 |
| -------- | :--: | :-----: | :----------: | ------------------------------------------ |
| Mentions | TODO |  TODO   |     TODO     | [Mentions](/rich-text-formatting/mentions) |
