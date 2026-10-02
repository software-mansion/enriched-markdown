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

The React Native package is what ships today, on iOS, Android, macOS and the
web. The [web build](/react-native/guides/web-support) covers
`EnrichedMarkdownText` only, and macOS runs the iOS code with a few gaps of its
own.

| Area | iOS / Android | macOS | Web |
| --- | :-: | :-: | :-: |
| CommonMark | Yes | Yes | Yes |
| GFM (tables, task lists, strikethrough, autolinks) | Yes | Yes | Yes |
| [Admonitions](/react-native/api-reference/element-structure#admonitions) | Yes | Yes | Yes |
| Extended Markdown (underline, superscript, subscript, highlight) | Yes | Yes | Yes |
| Spoilers | Yes | Yes | Planned |
| [Videos](/react-native/api-reference/element-structure#videos) | Yes | Yes | Planned |
| [LaTeX math](/rich-text-formatting/latex-math) | Yes | Inline only | Yes |
| [Code-block highlighting](/rich-text-formatting/code-highlighting) | Yes | Yes | Planned |
| [Markdown streaming](/rich-text-formatting/markdown-streaming) | Yes | Instant reveal | Planned |
| [Smart copy](/user-experience/copy-options) | Yes | Yes | Planned |
| [Accessibility](/user-experience/accessibility) | Yes | Planned | Partial |
| [RTL](/user-experience/rtl) | Yes | Yes | Container-level |
| `EnrichedMarkdownTextInput` (editor) | Yes | Yes | Planned |

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

### Web {#web}

The [web build](/react-native/guides/web-support) ships the renderer. Still to
come:

- **The editor.** `EnrichedMarkdownTextInput` has no web build at all.
- **Spoilers**, which are currently dropped along with their text - the most
  important gap on this list.
- **Videos**, which need a rebuild of the published WebAssembly parser.
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

- **Task list items** have no accessibility handling on either native platform -
  a checkbox is read as plain list text, with no state and no toggle action.
- **Admonitions** carry no accessibility role.

{/* UNRELEASED PLATFORMS: this page previously carried "In progress > Android
renderer", "In progress > iOS", "Planned > Native renderer parity", "The Compose
API surface" and "The editor on native", plus iOS and Android columns in the
status table. Five of those headings were inbound anchor targets from the ios/
and android/ trees (#android-renderer, #ios, #native-renderer-parity,
#the-compose-api-surface, #the-editor-on-native); restore the headings with the
same slugs when those trees are unhidden, or fix their inbound links in the same
commit.

Do not restore the old contents verbatim - several entries were stale:
- Android tables shipped in 0.2.0; LaTeX math and highlight renderers are the
  genuinely outstanding ones.
- The iOS block-image-sizing and per-paragraph-writing-direction items both
  landed.
- "Smart copy (Markdown, HTML, RTF, RTFD) | iOS | Yes" was wrong: the standalone
  iOS SDK writes plain text and HTML only, with no RTF or RTFD anywhere.
- "Block context menu on code blocks, tables, and block math" is done for tables
  on both packages and for block math on iOS; only code blocks and custom items
  remain.
- "Blockquotes already do this correctly on every package" was false for
  standalone Android, whose segment splitter emits only Text and Table segments.
- The page had no macOS column even though macOS is a shipped target. */}

## Asking for something

Need a feature that is not available yet, or need one of the planned items
sooner? Open an
[issue](https://github.com/software-mansion/enriched-markdown/issues) describing
what you are building - demand is what decides the order of this list. Pull
requests are welcome too, see [Contributing](/misc/contributing).
