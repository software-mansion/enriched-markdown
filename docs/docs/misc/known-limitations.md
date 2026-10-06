---
sidebar_label: Known limitations
sidebar_position: 3
---

# Known limitations

This section covers the rough edges worth knowing about before you hit them.
Deliberate behaviours, constraints imposed by the underlying text stacks, and a few things
that are simply not wired up yet.

This page covers `react-native-enriched-markdown` 1.1.1, including its web and
macOS targets.

:::note
It describes the state today. For what is being worked on and what is merely
planned, see the [Roadmap](/misc/roadmap); for the full per-feature matrix,
[Feature support](/introduction/supported-features).
:::

### Rendering

- **Text selection cannot span segments.** With
  [`flavor="github"`](/react-native/api-reference/enriched-markdown-text#flavor)
  the document is split into independent segments (tables, fenced code blocks,
  block math, blockquotes and admonitions each become their own view). This enables features like
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
- **Raw HTML is not rendered.** Inline HTML is disabled and HTML tags in the
  source are ignored. The one allowlisted exception is a block-level
  [`<video>`](/react-native/api-reference/element-structure#videos) tag, of which
  only `src` is read - all video styling comes from
  [`markdownStyle.video`](/react-native/api-reference/style-properties#video-specific).
- **`<br>` does not force a line break.** It is raw HTML like any other tag: an
  inline `<br>` stays in the output as literal text, and one on its own line is
  dropped. Use a hard break (two trailing spaces or a backslash) or
  [`hardSoftBreaks`](/react-native/api-reference/enriched-markdown-text#hardsoftbreaks).
  Parser-level support is [planned](/misc/roadmap), but nothing in the parser touches it today.
- **There is no `colorScheme` prop.** The library ships light-mode color
  defaults and leaves theming to you, exactly like React Native's `Text` - swap
  `markdownStyle` objects on `useColorScheme()`. See
  [Dark mode](/react-native/api-reference/style-properties#dark-mode).

### The editor

- **Block elements are limited.** [`EnrichedMarkdownTextInput`](/react-native/api-reference/enriched-markdown-text-input)
  supports headings and lists; anything else - code blocks, blockquotes, tables -
  needs the read-only renderer.
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

The full announcement model is in
[Accessibility](/user-experience/accessibility).

### Copy and clipboard

- **Copy-as-HTML carries one direction for the whole document**, and the two
  platforms derive it differently - iOS from the first paragraph, Android from
  the view's layout direction (and its table export carries none at all). A
  mixed-direction document will not paste with the per-paragraph layout you see
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
  served for a request with different ones. The library adds no `Vary` handling.
  See [Request headers](/react-native/guides/image-caching#request-headers).
- **The iOS disk cache ignores HTTP freshness.** Its session runs with
  `NSURLRequestReturnCacheDataElseLoad`, so a cached response is served
  regardless of its age or `max-age`. Android's OkHttp cache behaves normally.
- **The image caches are process-global and cannot be cleared.** There is no
  public API to inspect, clear, or invalidate them.
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

The web build renders `EnrichedMarkdownText` only - there is no editor.

:::danger
**Spoilers lose their content on web.** The parser emits a spoiler node, the web
renderer has none, and an unhandled node is dropped together with its subtree, so
`a ||secret|| b` renders as `a  b`. The concealed text is gone, not concealed.
:::

Also missing there: code-block syntax highlighting (fenced blocks render as plain
monospaced text, with no header or copy button),
[videos](/react-native/api-reference/element-structure#videos) - the published
WebAssembly parser predates the feature, so the tag produces no node - and any
clipboard integration at all. Every link opens in a new tab; `target` is not
configurable. There is no `flavor` prop: GFM is always on. LaTeX math needs the
optional `katex` peer dependency, falling back to raw `$...$` without it. The
accessibility strings are hard-coded English and `accessibilityLabels` is
stripped, as are a number of other native-only props. See
[Ignored props](/react-native/guides/web-support#ignored-props-native-only) and
[Not supported on web](/react-native/guides/web-support#not-supported-on-web).

### macOS

**Block math is silently dropped** under `flavor="github"` - the equation
produces no segment and no fallback text. Inline math renders. Beyond that: the
tail fade-in animation falls back to an instant reveal, system font-scale
changes are not observed, VoiceOver is stubbed, and `selectionColor` tints only
the selection background - AppKit's `NSTextView` does not expose caret and
handle tinting via `tintColor`. See
[macOS support](/react-native/guides/macos#known-limitations).

### Testing

The Jest mock does not parse or render Markdown - it mostly stores and echoes
raw text, so it is meant for testing your components' wiring rather than the
library's rendering. Its ref-method surface is type-checked against the real
component; its **props** are not, and a few display props are already
unforwarded. See [Testing](/react-native/guides/testing#limitations).

{/* UNRELEASED PLATFORMS: the standalone iOS and Android limitation lists lived
here and are NOT safe to restore verbatim - several entries went stale before
this page was hidden. Re-verify each against the packages before unhiding:

iOS: block image sizing now has maxHeight/aspectRatio/resizeMode (ImageStyle),
writing direction IS resolved per paragraph (WritingDirectionResolver), and a
block context menu DOES exist on tables and block math (only code blocks and
custom items are still missing). Still true: read-only, no container styling,
no image tap callback, no link previews, no flavor selector, no public
streaming API, no per-URL link variants or mentions, and no code-block syntax
highlighting (there is no tree-sitter target in Package.swift at all - the old
wording "optional and not compiled in" was misleading).

Android: tables ARE implemented and shipped in 0.2.0, and the table view has a
block context menu. Still true for the released version: spoilers, LaTeX math
and highlight are parsed but not drawn; the Compose wrapper does not expose
selection colors, font scaling, trailing margin, the copy actions, label
localization or break strategy; accessibility labels are hardcoded with no
override at any layer; the composable renders nothing in @Preview.

Also unrecorded anywhere: task-list accessibility is entirely absent from the
React Native package on both platforms, and onImagePress does not fire for
images inside GFM tables. */}

## Something missing?

If one of these blocks what you are building, say so in an
[issue](https://github.com/software-mansion/enriched-markdown/issues) - it is
how the [Roadmap](/misc/roadmap) gets ordered. Pull requests are welcome too,
see [Contributing](/misc/contributing).
