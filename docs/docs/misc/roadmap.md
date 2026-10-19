---
sidebar_label: Roadmap
sidebar_position: 4
---

# Roadmap

Where the library stands today and what is being worked on next. For what
already ships, see [Feature support](/introduction/supported-features), and for
the rough edges in what ships, [Known limitations](/misc/known-limitations) -
this page covers the gaps.

:::note
This is a snapshot, not a release plan: nothing here has a date, and the order
can change. **In progress** means the work is underway and expected in one of
the next releases; **planned** means it is on the list without a timeline yet.
:::

## Status at a glance

The React Native package ships on iOS, Android, macOS and the web - the
**iOS / Android** column below is that package. The
[web build](/react-native/guides/web-support) covers `EnrichedMarkdownText`
only, and macOS runs the iOS code with a few gaps of its own. The standalone
[iOS package](/ios/basics/installation) (0.4.0) and
[Android package](/android/basics/installation) (0.3.0) are renderers for
SwiftUI and Jetpack Compose apps, and have their own columns.

| Area | iOS / Android | iOS package | Android package | macOS | Web |
| --- | :-: | :-: | :-: | :-: | :-: |
| CommonMark | Yes | Yes | Yes | Yes | Yes |
| GFM (tables, task lists, strikethrough, autolinks) | Yes | Yes | Yes | Yes | Yes |
| [Admonitions](/react-native/api-reference/element-structure#admonitions) | Yes | Yes | Yes | Yes | Yes |
| Extended Markdown (underline, superscript, subscript, highlight) | Yes | Yes | Yes | Yes | Yes |
| Spoilers | Yes | Yes | Yes | Yes | Planned |
| [Videos](/react-native/api-reference/element-structure#videos) | Yes | Planned | Planned | Yes | Yes |
| [LaTeX math](/rich-text-formatting/latex-math) | Yes | Yes | Yes | Inline only | Yes |
| [Code-block highlighting](/rich-text-formatting/code-highlighting) | Yes | Yes | Yes | Yes | Planned |
| [Markdown streaming](/rich-text-formatting/markdown-streaming) | Yes | Planned | Planned | Instant reveal | Planned |
| [Smart copy](/user-experience/copy-options) | Yes | Plain text + HTML | Yes | Yes | Planned |
| [Accessibility](/user-experience/accessibility) | Yes | Yes | Partial | Planned | Partial |
| [RTL](/user-experience/rtl) | Yes | Yes | Yes | Yes | Container-level |
| `EnrichedMarkdownTextInput` (editor) | Yes | Planned | Planned | Yes | Planned |

In the native columns, LaTeX math comes from an optional add-on - the
`EnrichedMarkdownLaTeX` product on iOS, the `math` artifact on Android - and so
does code-block highlighting: the `EnrichedMarkdownSyntaxHighlighting` product on
iOS, the `code-highlight` artifact on Android. The iOS package's smart copy writes plain text and HTML, with no RTF
or RTFD flavor. The Android package's accessibility strings are hard-coded
English with no way to override them.

## In progress

### macOS

- **Block math.** A `$$...$$` equation under `flavor="github"` currently
  produces no segment and no fallback text, so it disappears from the output.
  Inline math renders correctly today.
- **VoiceOver**, pending an `NSAccessibility` implementation - a no-op stub
  ships now.
- **Tail fade-in animation**, which falls back to an instant reveal.
- **System font-scale observation.**

## Planned

### Container blocks

[Container blocks](https://spec.commonmark.org/0.31.2/#container-blocks) are the
elements that hold other blocks as children. Blockquotes already do this
correctly in the React Native package - a quote's content is a recursive
container that can nest paragraphs, code, and further quotes. We want the same
treatment for the other container types, so **all list kinds** (ordered,
unordered, and task lists) render arbitrary block content in their items the way
blockquotes do, on every target.

### Native renderer parity {#native-renderer-parity}

- **Block context menus.** Tables and block math have one on both native
  packages and code blocks have one on iOS; Android code blocks still have
  none, and neither package lets you add your own items.
- **Nested blocks on Android.** The Android segment splitter emits only Text,
  Table and Custom (plugin) segments, so a table inside a list item or
  blockquote is not rendered. Lists and blockquotes should hold arbitrary block
  content, as described under [Container blocks](#container-blocks).

### The Compose API surface {#the-compose-api-surface}

`EnrichedMarkdownText` on Android does not yet expose selection colors, font
scaling, the copy actions, label localization or break strategy, and
accessibility labels cannot be overridden at any layer.

### The editor on native {#the-editor-on-native}

Both native packages render Markdown but do not edit it; there is no editable
rich text field on either yet. On React Native,
[`EnrichedMarkdownTextInput`](/react-native/api-reference/enriched-markdown-text-input)
is available today.

### Web {#web}

The [web build](/react-native/guides/web-support) ships the renderer. Still to
come:

- **The editor.** `EnrichedMarkdownTextInput` has no web build at all.
- **Spoilers**, which are currently dropped along with their text - the most
  important gap on this list.
- **Code-block highlighting**, including the header and copy button.
- **[Streaming](/rich-text-formatting/markdown-streaming)** and
  **[smart copy](/user-experience/copy-options)**, neither of which has a web
  implementation.
- **Localizable accessibility strings.** Everything the web renderer speaks is
  hard-coded English today, and `accessibilityLabels` is stripped.
- **Per-paragraph direction.** Web resolves direction once, at the container
  level, rather than per paragraph as native does.

### Shared core

- **HTML line breaks (`<br>`)** - today the tag is raw HTML like any other: an
  inline `<br>` stays in the output as literal text, and one on its own line is
  dropped. Parser-level support is on the list, but no work has started.

### Accessibility

- **Task list items** have no accessibility handling in the React Native
  package, on either platform - a checkbox is read as plain list text, with no
  state and no toggle action.
- **Admonitions** carry no accessibility role.

## Asking for something

Need a feature that is not available yet, or need one of the planned items
sooner? Open an
[issue](https://github.com/software-mansion/enriched-markdown/issues) describing
what you are building - demand is what decides the order of this list. Pull
requests are welcome too, see [Contributing](/misc/contributing).
