---
sidebar_label: Known limitations
sidebar_position: 3
---

# Known limitations

This section covers the rough edges worth knowing about before you hit them.
Deliberate behaviours, constraints imposed by the underlying text stacks, and a few things
that are simply not wired up yet.

The three packages are grouped separately below. All of them parse through the
same C++ core, so Markdown **syntax** support is identical everywhere - the
differences are in rendering and in how much of each API surface is exposed.

:::note
This page describes the state today. For what is being worked on and what is
merely planned, see the [Roadmap](/misc/roadmap); for the full per-feature
matrix, [Feature support](/introduction/supported-features).
:::

## React Native

Covers `react-native-enriched-markdown`, including its web and macOS targets.

### Rendering

- **Text selection cannot span segments.** With
  [`flavor="github"`](/react-native/api-reference/enriched-markdown-text#flavor)
  the document is split into independent segments (tables, fenced code blocks,
  block math, and blockquotes each become their own view). This enables features like
  horizontal table scrolling and the block context menu. The tradeoff is that selection starts and
  ends inside one segment. `flavor="commonmark"` renders a single text view and
  selects across the whole document.
- **Clamping text with
  [`numberOfLines`](/react-native/api-reference/enriched-markdown-text#numberoflines)
  is CommonMark-only.** Under `flavor="github"` the content is laid out as
  independent block segments that cannot honor a document-wide line cap, so the
  prop is ignored, and so is
  [`ellipsizeMode`](/react-native/api-reference/enriched-markdown-text#ellipsizemode).
- **[Android] A clamped view is neither selectable nor tappable.** While
  `numberOfLines > 0`, text selection and link taps are off regardless of
  [`selectable`](/react-native/api-reference/enriched-markdown-text#selectable).
  This is a platform constraint: Android draws the truncation ellipsis only
  through `StaticLayout`, but enabling selection or a link movement method
  promotes the text to `DynamicLayout`, which has no `maxLines` support - React
  Native's own `Text` behaves the same way. Both are restored once the clamp is
  removed, and iOS keeps selection and links while clamped.
- **Superscript and subscript cannot nest inside each other.** They nest fine
  inside bold, italic, and links - see
  [Element structure](/react-native/api-reference/element-structure#superscript-and-subscript).
- **Raw HTML is not rendered.** Inline HTML is disabled and HTML tags in the
  source are ignored. The one allowlisted exception is a block-level
  [`<video>`](/react-native/api-reference/element-structure#videos) tag, of which
  only `src` is read - all video styling comes from
  [`markdownStyle.video`](/react-native/api-reference/style-properties#video-specific).
- **`<br>` does not force a line break.** It is raw HTML like any other tag: an
  inline `<br>` stays in the output as literal text, and one on its own line is
  dropped. Use a hard break (two trailing spaces or a backslash) or
  [`hardSoftBreaks`](/react-native/api-reference/enriched-markdown-text#hardsoftbreaks).
  Parser-level support is [planned](/misc/roadmap).
- **There is no `colorScheme` prop.** The library ships light-mode color
  defaults and leaves theming to you, exactly like React Native's `Text` - swap
  `markdownStyle` objects on `useColorScheme()`. See
  [Dark mode](/react-native/api-reference/style-properties#dark-mode).

### The editor

- **Block elements are limited.** [`EnrichedMarkdownTextInput`](/react-native/api-reference/enriched-markdown-text-input).
  Headings and lists are allowed; anything else (Codeblock, blockquote, etc.) needs the read-only renderer.
- **The input is uncontrolled by design.** The value lives in the native
  component rather than in React state - read it through `onChangeMarkdown` or
  `getMarkdown()`, and write it with `setValue()`. There is no `value` prop to
  drive it from a render.
- **The placeholder ignores [`writingDirection`](/react-native/api-reference/enriched-markdown-text-input#writingdirection).** It follows the host view's
  layout direction instead, so an RTL placeholder needs
  `<View style={{ direction: 'rtl' }}>` (or `I18nManager.forceRTL(true)`) around
  the input.
- **A fresh paragraph briefly inherits the previous direction.** The first
  characters typed into an empty paragraph take the preceding paragraph's base
  direction; the first-strong pass corrects it on the next input event.

### Accessibility

- **Inline formatting is not split into separate elements.** Bold, italic,
  underline, strikethrough, inline code, and spoiler are read as part of the
  surrounding paragraph - deliberate, since screen readers ignore visual
  emphasis by default. Only links and images become their own elements.
- **The rotor is an iOS concept.** `accessibilityLabels.rotor.*` names the
  categories VoiceOver's rotor cycles through; TalkBack has no equivalent
  control, so those fields apply on iOS only and the rest of
  `accessibilityLabels` works the same on both platforms.
- **The editor is a single VoiceOver element on iOS.** It reads its full plain
  text, is not announced with the native "text field" role, has no in-field
  cursor navigation or per-character echo, and refreshes its spoken value on
  re-focus rather than live.
- **iOS blockquote backgrounds** may break at link boundaries instead of
  spanning the full line. Visual only - it does not affect what is announced.

Details and the full announcement model are in
[Accessibility](/user-experience/accessibility#known-limitations).

### Copy and clipboard

- **Copy-as-HTML carries one direction for the whole document.** The HTML
  representation gets a single `dir` attribute read from the first paragraph, so
  a mixed-direction document may not paste with the per-paragraph layout you see
  in-app. Plain text and Markdown round-trip cleanly - see the
  [copy-as-HTML caveat](/user-experience/rtl#copy-as-html-caveat).
- **The system Copy item cannot be hidden**, only relabeled, through
  [`selectionMenuConfig`](/react-native/api-reference/enriched-markdown-text#selectionmenuconfig).
- **`onCopyPress` does not fire for [Copy as Markdown](/user-experience/copy-options#copy-as-markdown).**
  It covers code copied from a fenced block - the header copy button, the
  context-menu **Copy** action, and the VoiceOver copy action.

### Images

- **The disk cache keys on URL alone.** Memory tiers and request deduplication
  fold [`imageRequestHeaders`](/react-native/api-reference/enriched-markdown-text#imagerequestheaders)
  into the cache identity, but the disk layer is managed by the HTTP stack
  (OkHttp / `NSURLCache`), so a response fetched with one set of headers can be
  served for a request with different ones, subject to `Cache-Control` and
  `Vary`. See [Request headers](/react-native/guides/image-caching#request-headers).
- **`imageRequestHeaders` has no effect on web** - browsers do not allow custom
  headers on `<img>` requests.

### Installation and build

- **Yarn PnP is not supported.** PnP stores dependencies as read-only archives,
  so the postinstall cannot write the vendored native assets into the package.
  Use the `node-modules` linker, which is the norm for React Native projects
  anyway.
- **pnpm blocks the postinstall by default.** Recent pnpm skips dependency
  lifecycle scripts unless the package is listed in `onlyBuiltDependencies`;
  without it the native build fails until the assets are downloaded manually.
- **`--ignore-scripts` and offline installs skip the asset download.** Nothing
  fails at install time - it surfaces later as a native build error. See
  [Requirements](/react-native/guides/native-assets#requirements) and
  [Recovering a failed download](/react-native/guides/native-assets#recovering-a-failed-or-skipped-download).
- **Expo Go cannot change compiled-in features.** Code highlighting and LaTeX
  math are compiled into the binary, and Expo Go ships a fixed prebuilt one -
  use a development build or `expo prebuild`. See
  [Expo](/react-native/basics/installation#expo).
- **iOS needs `pod install` plus a clean build after changing the
  `enriched-markdown` block.** The podspec reads `package.json` at install time,
  and Xcode's incremental build does not reliably relink the pod's static
  library when only its source list changes. Android reconfigures on every
  build. See [Reducing binary size](/react-native/guides/native-assets#reducing-binary-size).

### Web

The web build renders `EnrichedMarkdownText` only. It has no editor, no spoiler
concealment, no code-block syntax highlighting (fenced blocks render as
plain monospaced text), and no [video](/react-native/api-reference/element-structure#videos)
support - the `<video>` tag is not parsed there. Every link opens in a new tab -
`target` is not configurable. A handful of native-only props are accepted and ignored. See
[Ignored props](/react-native/guides/web-support#ignored-props-native-only) and
[Not supported on web](/react-native/guides/web-support#not-supported-on-web).

### macOS

LaTeX math is not enabled, the tail fade-in animation falls back to an instant
reveal, system font-scale changes are not observed, VoiceOver is stubbed, and
`selectionColor` tints only the selection background - AppKit's `NSTextView`
does not expose caret and handle tinting via `tintColor`. See
[macOS support](/react-native/guides/macos#known-limitations).

### Testing

The Jest mock does not parse or render Markdown - it stores and echoes raw
text, so it is meant for testing your components' wiring rather than the
library's rendering. See [Testing](/react-native/guides/testing#limitations).

## iOS

Covers the standalone iOS package. It renders CommonMark, GFM, and LaTeX math,
but through its own TextKit stack, so it trails the React Native package in
rendering features and API surface.

- **Read-only.** There is no `EnrichedMarkdownTextInput` equivalent, so inline
  and block formatting, the format bar, and the imperative editing API are React
  Native only.
- **Block image sizing is limited** to height and corner radius - `maxHeight`,
  `aspectRatio`, and `resizeMode` have no equivalent yet.
- **Writing direction is not resolved per paragraph.** The first-strong
  resolution described in [RTL support](/user-experience/rtl) has not reached the native
  package, so paragraph direction follows the app's UI layout direction.
- **No container styling.** The API exposes per-element margins and a wrapping
  view, with no equivalent of `containerStyle`.
- **Images are not tappable** - there is no image tap callback.
- **No block context menu** on code blocks, tables, or block math, and no
  custom context-menu items.
- **No link previews.**
- **No flavor selector.** GFM is toggled through individual md4c flags instead
  of a single `flavor` prop, and tables are always enabled.
- **No public streaming API** - see
  [Markdown streaming](/rich-text-formatting/markdown-streaming).
- **No per-URL link variants**, and with them no
  [mentions](/rich-text-formatting/mentions) - the package has no mention node
  or renderer.
- **No code-block syntax highlighting** - the tree-sitter module is optional
  and is not compiled into the package. See
  [Code-block highlighting](/rich-text-formatting/code-highlighting).

## Android

Covers the standalone Android package. The parser emits every node the other
packages do; several renderers and a slice of the Compose API are still catching
up.

- **Read-only**, like the iOS package - no editor equivalent.
- **Missing renderers.** GFM tables, LaTeX math, spoilers, and highlight
  (`==text==`) are parsed but not yet drawn.
- **Parts of the view are not reachable from Compose.** Selection color,
  selection handle color, font scaling, trailing margin, the *Copy as Markdown*
  and *Copy image URL* actions, accessibility label localization, and the text
  break strategy exist in the underlying span-based view but are not exposed by
  the `compose` wrapper.
- **Smart copy is partial.** The plain-text and HTML clipboard write works; the
  dedicated *Copy as Markdown* and *Copy image URL* actions are not exposed by
  the Compose API. See [Copy options](/user-experience/copy-options).
- **Accessibility labels are hardcoded.** List and heading labels are in place,
  but there is no localization prop - table, math, and blockquote labels follow
  the renderers above.
- **Block image sizing is limited** to height and corner radius, as on iOS.
- **The same API gaps as iOS** otherwise: no container styling, no image tap
  callbacks, no block context menu or custom context-menu items, no link
  previews, no flavor selector, no public streaming API (the fade-in machinery
  exists internally), no per-URL link variants or mentions, and no code-block
  syntax highlighting.

## Something missing?

If one of these blocks what you are building, say so in an
[issue](https://github.com/software-mansion/enriched-markdown/issues) - it is
how the [Roadmap](/misc/roadmap) gets ordered. Pull requests are welcome too,
see [Contributing](/misc/contributing).
