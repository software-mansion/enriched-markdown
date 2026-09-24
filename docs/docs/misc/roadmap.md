---
sidebar_label: Roadmap
sidebar_position: 4
---

# Roadmap

Where each package stands today and what is being worked on next. For what
already ships, see [Feature support](/introduction/supported-features), and for
the rough edges in what ships, [Known limitations](/misc/known-limitations) -
this page covers the gaps.

:::note
This is a snapshot, not a release plan: nothing here has a date, and the order
can change. **In progress** means the work is underway and expected in one of
the next releases; **planned** means it is on the list without a timeline yet.
:::

## Status at a glance

The React Native package leads. The standalone iOS and Android packages parse
through the same C++ core, so syntax support arrives everywhere at once, but
each renders with its own text stack and trails React Native in rendering
features. The [web build](/react-native/guides/web-support) covers
`EnrichedMarkdownText` only.

| Area | React Native | Web | iOS | Android |
| --- | :-: | :-: | :-: | :-: |
| CommonMark | Yes | Yes | Yes | Yes |
| GFM (tables, task lists, strikethrough, autolinks) | Yes | Yes | Yes | Tables in progress |
| Extended Markdown (underline, superscript, subscript, highlight, spoiler) | Yes | No spoiler | Yes | Spoiler in progress, highlight planned |
| [LaTeX math](/rich-text-formatting/latex-math) | Yes | Yes | Yes | In progress |
| [Markdown streaming](/rich-text-formatting/markdown-streaming) | Yes | Planned | Planned | Planned |
| [Smart copy](/user-experience/copy-options) (Markdown, HTML, RTF, RTFD) | Yes | Planned | Yes | Partial |
| [Accessibility](/user-experience/accessibility) & [RTL](/user-experience/rtl) | Yes | Yes | Yes | Partial |
| `EnrichedMarkdownTextInput` (editor) | Yes | Planned | Planned | Planned |

Where the table says **Partial** on Android:

- **Smart copy** - the plain-text and HTML clipboard write works; the dedicated
  *Copy as Markdown* and *Copy image URL* actions exist in the view but are not
  exposed by the Compose API yet.
- **Accessibility** - list and heading labels are in place; table, math, and
  blockquote labels follow the renderers below, and the label strings are
  hardcoded (no localization prop yet).

## In progress

### Android renderer

The parser already emits these nodes on Android - what is missing is the
renderer, so each of these is close.

- **GFM tables**, rendered as scrollable view segments.
- **LaTeX math**, inline and block.
- **Spoilers**, including the spoiler overlay.

### iOS

- **Block image sizing** - `maxHeight`, `aspectRatio`, and `resizeMode`. Both
  native packages currently size images through height and corner radius only.
- **Per-paragraph writing direction** - the first-strong resolution described in
  [RTL support](/user-experience/rtl), brought to the iOS package.

### Shared core

- **HTML line breaks (`<br>`)** - the tag is being added to the parser; the
  renderers follow once it lands.

## Planned

### Container blocks

[Container blocks](https://spec.commonmark.org/0.31.2/#container-blocks) are the
elements that hold other blocks as children. Blockquotes already do this
correctly on every package - a quote's content is a recursive container that can
nest paragraphs, code, and further quotes. We want the same treatment for the
other container types, so **all list kinds** (ordered, unordered, and task
lists) render arbitrary block content in their items the way blockquotes do,
uniformly across React Native, web, iOS, and Android.

### Native renderer parity

Available in React Native, not in either native package yet:

- **Container styling** - the native APIs expose per-element margins and a
  modifier or view, with no equivalent of `containerStyle`.
- **Image tap callbacks** - images are not tappable in either package.
- **Block context menu** on code blocks, tables, and block math.
- **Link previews.**
- **A single flavor selector** - both packages toggle GFM through individual
  md4c flags instead, and tables are always enabled.
- **[Markdown streaming](/rich-text-formatting/markdown-streaming)** - Android
  has the fade-in machinery internally, but no public streaming API.
- **Custom context-menu items.**
- **Per-URL link variants**, and with them
  [mentions](/rich-text-formatting/mentions) - neither package has a mention
  node or renderer.
- **[Code-block syntax highlighting](/rich-text-formatting/code-highlighting)** -
  the tree-sitter module is optional and is not compiled into either package.

Android additionally has no renderer for **highlight** (`==text==`) yet, even
though the parser produces the node.

### The Compose API surface

Several Android capabilities exist in the underlying span-based view but are not
reachable from the `compose` wrapper. Exposing them is planned:
selection color and selection handle color, font scaling, trailing margin, the
*Copy as Markdown* and *Copy image URL* actions, accessibility label
localization, and the text break strategy.

### Web

The [web build](/react-native/guides/web-support) ships the renderer.
Still to come: the editor, [streaming](/rich-text-formatting/markdown-streaming),
[smart copy](/user-experience/copy-options), and spoilers.

### The editor on native

The standalone iOS and Android packages are read-only renderers today - there is
no `EnrichedMarkdownTextInput` equivalent in either, so inline and block
formatting, the format bar, and the imperative editing API are React Native only.
Bringing the editor to the native packages is planned; there is no date for it.

## Asking for something

Need a feature that is not available yet, or need one of the planned items
sooner? Open an
[issue](https://github.com/software-mansion/enriched-markdown/issues) describing
what you are building - demand is what decides the order of this list. Pull
requests are welcome too, see [Contributing](/misc/contributing).
