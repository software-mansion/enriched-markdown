---
sidebar_label: EnrichedMarkdownText
sidebar_position: 1
---

import LivePreview from '@site/src/components/LivePreview';

import MarkdownSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/Markdown';
import MarkdownStyleSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/MarkdownStyle';
import ContainerStyleSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/ContainerStyle';
import FlavorSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/Flavor';
import Md4cUnderlineSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/Md4cUnderline';
import Md4cSuperscriptSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/Md4cSuperscript';
import Md4cSubscriptSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/Md4cSubscript';
import Md4cHighlightSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/Md4cHighlight';
import Md4cLatexMathSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/Md4cLatexMath';
import Md4cHardSoftBreaksSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/Md4cHardSoftBreaks';
import Md4cPreserveBlankLinesSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/Md4cPreserveBlankLines';
import Md4cAdmonitionsSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/Md4cAdmonitions';
import OnLinkPressSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/OnLinkPress';
import OnLinkLongPressSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/OnLinkLongPress';
import LinkPillContentSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/LinkPillContent';
import LinkContextMenuItemsSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/LinkContextMenuItems';
import OnImagePressSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/OnImagePress';
import OnTaskListItemPressSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/OnTaskListItemPress';
import EnableTaskListItemToggleSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/EnableTaskListItemToggle';
import EnableBlockContextMenuSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/EnableBlockContextMenu';
import OnCopyPressSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/OnCopyPress';
import OnCodeBlockPressSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/OnCodeBlockPress';
import OnLatexErrorSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/OnLatexError';
import EnableLinkPreviewSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/EnableLinkPreview';
import SelectableSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/Selectable';
import SelectionColorSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/SelectionColor';
import SelectionHandleColorSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/SelectionHandleColor';
import AllowFontScalingSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/AllowFontScaling';
import MaxFontSizeMultiplierSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/MaxFontSizeMultiplier';
import AllowTrailingMarginSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/AllowTrailingMargin';
import StreamingAnimationSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/StreamingAnimation';
import StreamingConfigSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/StreamingConfig';
import SpoilerOverlaySrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/SpoilerOverlay';
import ImageRequestHeadersSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/ImageRequestHeaders';
import ContextMenuItemsSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/ContextMenuItems';
import SelectionMenuConfigSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/SelectionMenuConfig';
import AccessibilityLabelsSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/AccessibilityLabels';
import NumberOfLinesSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/NumberOfLines';
import EllipsizeModeSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/EllipsizeMode';
import TextBreakStrategySrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/TextBreakStrategy';
import LineBreakStrategyIOSSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/LineBreakStrategyIOS';
import WritingDirectionSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/WritingDirection';
import DirSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/Dir';

# EnrichedMarkdownText

`EnrichedMarkdownText` renders Markdown content as fully native text - no WebView required. It parses Markdown with [md4c](https://github.com/mity/md4c) and paints it with the platform's native text stack (`TextKit` on iOS, `TextView` on Android), so selection, accessibility, and font scaling all behave like first-class native text.

```tsx
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { Linking } from 'react-native';

export default function App() {
  return (
    <EnrichedMarkdownText
      markdown={
        '# Hello\n\nA paragraph with **bold** and a [link](https://reactnative.dev).'
      }
      onLinkPress={({ url }) => Linking.openURL(url)}
    />
  );
}
```

## Props

`EnrichedMarkdownText` accepts every prop below. On iOS and Android it also forwards the standard React Native [`View`](https://reactnative.dev/docs/view#props) props - such as `testID`, `onLayout`, `pointerEvents`, `hitSlop`, and the `accessibility*` props - to the underlying native view. The one exception is `style`: use [`containerStyle`](#containerstyle) instead. It maps to the wrapper view's `style`, and is renamed so it is not mistaken for styling the Markdown text - that is [`markdownStyle`](#markdownstyle).

:::caution
The web build does **not** implement React Native `View` props. Its props type is `HTMLAttributes<HTMLDivElement>` plus `testID` (which becomes `data-testid`), and any unrecognized prop is spread onto the root `<div>`, so passing `pointerEvents` or `hitSlop` there produces React unknown-prop warnings. Use `id`, `aria-*` and CSS instead. See [Web support](/react-native/guides/web-support).
:::

All the shapes printed inline below (`Md4cFlags`, `StreamingConfig`, `AccessibilityLabels` and the rest) are exported types you can import from the package root. Note the `Text` prefix on three of them: `TextContextMenuItem`, `TextSelectionMenuConfig` and `TextSelectionMenuPluralLabels` are this component's types, because the unprefixed names belong to [`EnrichedMarkdownTextInput`](/react-native/api-reference/enriched-markdown-text-input).

:::note
Each prop has a live playground below - edit the code and try it. Props marked with a <IosBadge />, <AndroidBadge />, or <WebBadge /> badge only take effect on that platform - they are flagged with a matching colored dot in the table of contents.
:::

### `markdown`

The Markdown content to render. Which syntax elements are recognized depends on the [`flavor`](#flavor) and the [`md4cFlags`](#md4cflags) you set. To learn more, see [Feature support](/introduction/supported-features).

<PropInfo type="string" required />

<LivePreview src={MarkdownSrc} />

### `linkRecognition`

Opt-in link recognition for text that is not written as a Markdown link, such as `#1234`, `@name`, `$skill` or a file path. Off by default. Works in both flavors on every platform.

| Key | Type | Matches |
| --- | ---- | ------- |
| `text` | `RegExp` | Every nonempty, non-overlapping match inside a plain-text run |
| `inlineCode` | `RegExp` | An inline-code span whose whole content matches becomes one link |

A recognized link's URL is the matched text itself, so `linkVariants`, `linkPillContent`, `linkContextMenuItems`, `onLinkPress` and `onLinkLongPress` apply to it like to any other link. Existing links, autolinks, code blocks, images, video and math are never touched. The Markdown source is unchanged: copying, including Copy as Markdown, returns the original text without link syntax.

Matching happens per parsed text run, after Markdown parsing, so a pattern cannot match across formatting. `__init__.py` as plain text is split by emphasis parsing and will not match, while `` `__init__.py` `` as inline code matches whole. With the `latexMath` flag on (the default), two `$` on one line form a math span, so `$deploy ... $test` is math, not two skills; turn the flag off or escape the `$` in such content.

Only the regex source and the `i` and `s` flags are used. Patterns must be valid for `NSRegularExpression` and `java.util.regex.Pattern` as well as JavaScript; an invalid pattern turns that recognizer off. This is different from the input's `linkRegex`, which detects URLs and is on by default. Pass the object inline or hoisted as you like: an equal config does not re-send the prop.

```tsx
<EnrichedMarkdownText
  markdown="Fixed in #1284, see `src/App.tsx`"
  linkRecognition={{ text: /#\d+/, inlineCode: /[\w./-]+\.tsx?/ }}
  markdownStyle={{ linkVariants: { '^#\\d+$': { pill: true } } }}
  onLinkPress={({ url }) => openReference(url)}
/>
```

### `markdownStyle`

Style configuration for Markdown elements. See the [Style properties reference](/react-native/api-reference/style-properties) for the full list of styleable properties.

<PropInfo type="MarkdownStyle" default="{}" />

<LivePreview src={MarkdownStyleSrc} />

### `containerStyle`

Style for the view that wraps the rendered Markdown. `ViewStyle` and `TextStyle` are React Native's own style types: in practice you use the [`ViewStyle`](https://reactnative.dev/docs/view-style-props) layout and appearance properties here: `padding`, `margin`, `backgroundColor`, `borderRadius`, `borderWidth`, and the [flexbox](https://reactnative.dev/docs/flexbox) props. [`TextStyle`](https://reactnative.dev/docs/text-style-props) is accepted for parity, but to style the text itself (headings, links, code, and other elements) use [`markdownStyle`](#markdownstyle) instead.

:::note
`containerStyle` is React Native's regular `style` prop, renamed. It is handed straight to the wrapper `<View>`, so `ViewStyle` values (`padding`, `margin`, `backgroundColor`, the flexbox props) behave exactly as on any React Native view. It is renamed because the renderer is text-like: a prop called `style` would imply it styles the Markdown text, but the text is styled per element through [`markdownStyle`](#markdownstyle). `containerStyle` styles only the box around it.
:::

:::caution
On web, `containerStyle` is typed as React's `CSSProperties` and is spread straight onto the root `<div>`, so React Native shorthands do not apply: write `paddingLeft`/`paddingRight` rather than `paddingHorizontal`, `marginTop`/`marginBottom` rather than `marginVertical`, and `fontWeight: 'bold'` rather than `fontWeight: 700`. The web type also omits `style` entirely - `containerStyle` is the only way to style the container there.
:::

<PropInfo type="ViewStyle | TextStyle" />

<LivePreview src={ContainerStyleSrc} />

### `flavor`

Markdown flavor. `'commonmark'` (default) renders the whole document as a single text view. `'github'` splits the AST into segments, which changes both what is parsed and how it is rendered.

[Markdown flavors](/react-native/guides/markdown-flavors#what-gfm-adds) is the canonical list of what the switch changes - parsing, rendering, and the two things you give up under `github` ([`numberOfLines`](#numberoflines) / [`ellipsizeMode`](#ellipsizemode) are ignored, and text selection cannot span segments). Extra inline syntax (underline, highlight, super/subscript, math) is enabled separately through [`md4cFlags`](#md4cflags), independent of the flavor.

<PropInfo type="'commonmark' | 'github'" default="'commonmark'" />

<LivePreview src={FlavorSrc} unavailable unavailableReason={<>iOS and Android only - the web build always parses GitHub extensions, so there is no flavor switch.</>} />

### `md4cFlags`

Toggles for md4c's parser extensions; each opts a piece of extra inline syntax in or out. Pass only the flags you want to change; the rest keep their defaults below. Where a flag enables a new inline element, tune its appearance through the matching [style property](/react-native/api-reference/style-properties).

<PropInfo type="Md4cFlags" default="{ underline: false, superscript: false, subscript: false, highlight: false, latexMath: true, hardSoftBreaks: false, preserveBlankLines: false, admonitions: true }" />

#### `underline`

When `true`, the `_` character stops meaning emphasis entirely and starts meaning underline: `_text_` is underlined, and `__text__` becomes *doubly* underlined rather than bold. Only `*text*` and `**text**` still produce italic and bold, which is why the `*` forms are the safer ones to author with.

<PropInfo type="boolean" default="false" />

<LivePreview src={Md4cUnderlineSrc} />

#### `superscript`

When `true`, parses `^text^` as superscript.

<PropInfo type="boolean" default="false" />

<LivePreview src={Md4cSuperscriptSrc} />

#### `subscript`

When `true`, parses `~text~` as subscript. When disabled, `~` means nothing on its own; `~~text~~` is strikethrough, but only under [`flavor="github"`](#flavor) - under `commonmark` the tildes render literally.

<PropInfo type="boolean" default="false" />

<LivePreview src={Md4cSubscriptSrc} />

#### `highlight`

When `true`, parses `==text==` as highlighted spans. When disabled, double equals signs are treated as plain text.

<PropInfo type="boolean" default="false" />

<LivePreview src={Md4cHighlightSrc} />

#### `latexMath`

When `true`, parses `$...$` as inline math and `$$...$$` as display (block) math. Rendering on web uses [KaTeX](https://katex.org/) and natively [RaTeX](https://ratex.lites.dev/). Unlike the other flags on this page, `latexMath` is enabled by default - set it to `false` to treat dollar signs as plain text.

<PropInfo type="boolean" default="true" />

<LivePreview src={Md4cLatexMathSrc} />

#### `hardSoftBreaks`

When `true`, treats single newlines (soft breaks) as hard breaks, rendering them as visible line breaks instead of collapsing them into spaces. See [Line breaks](/react-native/api-reference/element-structure#line-breaks) for details.

<PropInfo type="boolean" default="false" />

<LivePreview src={Md4cHardSoftBreaksSrc} />

#### `preserveBlankLines`

When `true`, preserves runs of consecutive blank lines from the source instead of collapsing them into a single paragraph break (per CommonMark). Each blank line renders as one empty line, so the output keeps the exact line count that was typed. Pair it with `hardSoftBreaks` and zeroed paragraph margins to reproduce content authored in `EnrichedMarkdownTextInput` line for line - see the [Editor-style text](/rich-text-formatting/editor-style-text) guide, or [Blank lines](/react-native/api-reference/element-structure#blank-lines) for the element detail.

<PropInfo type="boolean" default="false" />

<LivePreview src={Md4cPreserveBlankLinesSrc} />

#### `admonitions`

Renders GitHub-style admonitions (also called alerts): a blockquote whose first line is `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, or `> [!CAUTION]` becomes a themed callout with an icon and a title header instead of a plain quote. Unlike the other flags, this one is **on by default**.

Admonitions inherit the blockquote's geometry and override only its colors, so restyle them through [`markdownStyle.blockquote.admonitions`](/react-native/api-reference/style-properties#admonitions) - see that section for the per-type palette.

:::note
Only takes effect with [`flavor="github"`](#flavor). Under `flavor="commonmark"` the flag is forced off and `> [!NOTE]` renders as an ordinary blockquote with the literal text.
:::

<PropInfo type="boolean" default="true" />

<LivePreview src={Md4cAdmonitionsSrc} />

### `enableTaskListItemToggle`

Controls whether tapping a task list checkbox toggles its checked state. When `false`, the checkbox renders its Markdown state read-only and the tap is **fully inert**; no visual toggle and `onTaskListItemPress` does not fire. Text selection and links in the same row are unaffected. Task lists themselves need [`flavor="github"`](#flavor), so this prop has nothing to act on under `commonmark`.

<PropInfo type="boolean" default="true" />

<LivePreview src={EnableTaskListItemToggleSrc} />

### `enableBlockContextMenu`

Controls the long-press context menu on block views - fenced code blocks, tables, and block math. When `false`, long-pressing a block no longer opens the copy popup. It does not affect the code-block header copy button, the VoiceOver / TalkBack copy action, or the system text-selection menu. To hide individual built-in actions while keeping the menu, use [`selectionMenuConfig`](#selectionmenuconfig) instead - see [Copy options](/user-experience/copy-options#controlling-the-built-in-menu).

<PropInfo type="boolean" default="true" />

<LivePreview src={EnableBlockContextMenuSrc} unavailable unavailableReason={<>iOS, Android, and macOS only - the block context menu is a native interaction, and the web build renders blocks without one.</>} />

### `enableLinkPreview` <IosBadge /> {#enablelinkpreview}

Controls the native link preview on long press. It is on by default, and supplying [`onLinkLongPress`](#onlinklongpress) turns it off - your handler owns the long press instead. That override cannot be undone from this prop: with `onLinkLongPress` set, even an explicit `enableLinkPreview={true}` is discarded. Setting [`selectable={false}`](#selectable) also suppresses the preview.

<PropInfo type="boolean" default="true" />

<LivePreview src={EnableLinkPreviewSrc} unavailable unavailableReason={<>iOS only - the system link preview is an iOS feature.</>} />

### `selectable`

Whether text can be selected. On web, `false` applies `user-select: none`. On iOS it also suppresses the long-press link preview (see [`enableLinkPreview`](#enablelinkpreview)).

<PropInfo type="boolean" default="true" />

<LivePreview src={SelectableSrc} />

### `selectionColor`

Color of the text selection highlight. On iOS this also tints the caret and selection handles (they share one tint). On macOS, only the selection background is affected. On Android, use [`selectionHandleColor`](#selectionhandlecolor) to override the handle color independently.

<PropInfo type="ColorValue" typeHref="https://reactnative.dev/docs/colors" />

<LivePreview src={SelectionColorSrc} />

### `selectionHandleColor` <AndroidBadge /> {#selectionhandlecolor}

Color of the selection handles (drag anchors). No-op on Android API levels below 29.

<PropInfo type="ColorValue" typeHref="https://reactnative.dev/docs/colors" />

<LivePreview src={SelectionHandleColorSrc} unavailable unavailableReason={<>Android only - selection handles are an Android control.</>} />

### `allowFontScaling`

Whether fonts should scale to respect the OS Text Size accessibility setting.

<PropInfo type="boolean" default="true" />

<LivePreview src={AllowFontScalingSrc} unavailable unavailableReason={<>iOS and Android only - on web, text is forced to scale with the browser.</>} />

### `maxFontSizeMultiplier`

Maximum font scale multiplier when `allowFontScaling` is enabled. `undefined` or `0` means no limit; a value `>= 1` caps the multiplier.

<PropInfo type="number" default="undefined" />

<LivePreview src={MaxFontSizeMultiplierSrc} unavailable unavailableReason={<>iOS and Android only - on web, text is forced to scale with the browser.</>} />

### `allowTrailingMargin`

Whether to preserve the bottom margin of the last block element. When `false` (default), the trailing margin is removed to eliminate bottom spacing.

<PropInfo type="boolean" default="false" />

<LivePreview src={AllowTrailingMarginSrc} />

### `streamingAnimation`

When `true`, newly appended content fades in during streaming updates. Only the tail is animated, and the tail is found by **length**, not by diffing: everything past the previous content's length fades in. Streaming therefore assumes append-only updates - replacing `markdown` wholesale (a retry or a regeneration) will not fade correctly. Recommended for LLM streaming use cases.

<PropInfo type="boolean" default="false" />

<LivePreview src={StreamingAnimationSrc} unavailable unavailableReason={<>iOS, Android, and macOS only - the fade-in animation is native. On macOS it degrades to an instant reveal.</>} />

### `streamingConfig`

Fine-grained control over how incomplete tables and fenced code blocks are handled while streaming. Two conditions must both hold for it to do anything: `streamingAnimation` must be `true`, **and** the flavor must be `github` - the filter runs only on the segmented renderer, so under `flavor="commonmark"` you get the tail fade and nothing else.

<PropInfo type="StreamingConfig" default="{ tableMode: 'progressive', codeBlockMode: 'progressive' }" />

```ts
interface StreamingConfig {
  tableMode?: 'hidden' | 'progressive';
  codeBlockMode?: 'hidden' | 'progressive';
}
```

<LivePreview src={StreamingConfigSrc} unavailable unavailableReason={<>iOS and Android only - streaming block handling is native.</>} />

- `tableMode`
  - `'progressive'` **(default)** renders the table row-by-row as content arrives (incomplete trailing rows are trimmed).
  - `'hidden'` withholds the table until it is complete.
- `codeBlockMode`
  - `'progressive'` **(default)** streams the code in with a visible but non-interactive header and defers syntax highlighting until the closing fence arrives.
  - `'hidden'` withholds the block until it is complete.

An unterminated block-math (`$$`) block is also withheld until its closing `$$` arrives. That behavior is unconditional and has no key here.

### `spoilerOverlay`

Controls how spoiler text (`||hidden text||`) is displayed before being revealed. Both modes support tap-to-reveal.

<PropInfo type="'particles' | 'solid'" default="'particles'" />

:::danger
The web build has no spoiler renderer at all, and an unhandled node is dropped **together with its subtree** - so `a ||secret|| b` renders as `a  b` with the concealed text missing, not concealed. Do not place content behind a spoiler if the same Markdown is also rendered on web.
:::

<LivePreview src={SpoilerOverlaySrc} unavailable unavailableReason={<>iOS and Android only - the web build drops spoiler nodes entirely.</>} />

- **`'particles'`**: animated particle overlay (CAEmitterLayer on iOS, Choreographer-driven Canvas particles on Android).
- **`'solid'`**: opaque rectangle covering the text (Discord-style).

### `imageRequestHeaders`

HTTP headers attached to remote image requests, e.g. a `Referer` required by CDN hotlink protection or an `Authorization` token. Headers participate in image cache identity, so the same URL requested with different headers is fetched and cached separately - see [Image caching](/react-native/guides/image-caching#request-headers) for the details and the disk-cache caveat.

<PropInfo type="Record<string, string>" />

<LivePreview src={ImageRequestHeadersSrc} unavailable unavailableReason={<>Not supported on web - browsers don't allow custom headers on <code>&lt;img&gt;</code> requests.</>} />

### `linkPillContent`

Per-link content for [link pills](/react-native/guides/link-pills): a label, icon and icon tint for one exact link URL. It only affects links whose `markdownStyle.linkVariants` entry enables `pill`, and wins over that variant's `pill.label`, `pill.iconUri` and `pill.iconTintColor`. This is content, not style: keep `markdownStyle` stable and change this map as links appear, and keep the object reference stable between renders when its content has not changed.

<PropInfo type="Record<string, LinkPillContent>" />

```ts
interface LinkPillContent {
  /** Replaces the pill's label. Falls back to the variant's `pill.label`, then the link text. */
  label?: string;
  /** Icon shown before the label - a bundled asset name, file path, `data:` or `http(s)` URI. */
  iconUri?: string;
  /** Tints this link's icon and keeps its alpha. Omit to keep the icon's own colors. */
  iconTintColor?: string;
}
```

<LivePreview src={LinkPillContentSrc} unavailable unavailableReason={<>iOS and Android only - pills are drawn by the native text stack.</>} />

### `contextMenuItems`

Custom items to add to the text selection context menu. Items appear before the system actions and are hidden when `visible: false`. On iOS this requires iOS 16+; on earlier versions the prop is ignored.

<PropInfo type="TextContextMenuItem[]" />

:::note
The exported type is `TextContextMenuItem`. The unprefixed `ContextMenuItem` export is the **editor's** item type, whose `onPress` payload carries an extra `styleState` field.
:::

```ts
interface TextContextMenuItem {
  /** Label shown in the context menu. */
  text: string;
  /** SF Symbol name for the item icon (iOS/macOS only; ignored on Android). */
  icon?: string;
  onPress: (event: {
    /** The selected text at the time of the press. */
    text: string;
    /** Absolute character range of the selection within the full content. */
    selection: { start: number; end: number };
  }) => void;
  /** When false, the item is not shown. Defaults to true. */
  visible?: boolean;
}
```

<LivePreview src={ContextMenuItemsSrc} unavailable unavailableReason={<>iOS, Android, and macOS only - it customizes the native selection menu.</>} />

### `linkContextMenuItems` <IosBadge /> {#linkcontextmenuitems}

Items of the native menu shown when a link is long-pressed, on iOS 17 and later. Keys are URL regex patterns matched like `markdownStyle.linkVariants`: the longest pattern that matches a link's URL supplies its menu, so one entry covers every link of a kind, and a pattern anchored to one URL gives that link its own menu. See [Link menus](/react-native/guides/link-menus) for the full behavior.

A link with a menu shows it instead of [`onLinkLongPress`](#onlinklongpress) and the system link preview. The menu holds only your items and is titled with the link's text, or its [pill](/react-native/guides/link-pills) label. A link that matches no pattern, or whose pattern has no visible items, keeps its existing long-press behavior. Android, macOS and iOS below 17 ignore this prop; keep `onLinkLongPress` for them.

<PropInfo type="Record<string, LinkContextMenuItem[]>" />

```ts
interface LinkContextMenuItem {
  /** Label shown in the menu. Identifies the item, so unique within one pattern. */
  text: string;
  /** SF Symbol name, as in `contextMenuItems`. */
  icon?: string;
  /** Receives the link's original URL, including relative paths. */
  onPress: (event: { url: string }) => void;
  /** When false, the item is not shown. Defaults to true. */
  visible?: boolean;
  /** Shown but not tappable. Defaults to false. */
  disabled?: boolean;
  /** Styled as a destructive action. Defaults to false. */
  destructive?: boolean;
}
```

:::note
The library does not navigate or copy for these items; do that in `onPress`. A menu can stay open while the prop changes: a press on an item the current value no longer offers (removed, hidden or disabled) is ignored.
:::

<LivePreview src={LinkContextMenuItemsSrc} unavailable unavailableReason={<>iOS 17 and later only - the menu is the native link context menu.</>} />

### `selectionMenuConfig`

Controls the built-in actions in the native text selection menu (and the table/math copy menus) and lets you localize their labels. Custom app actions are controlled separately with `contextMenuItems`. Each item takes an object: `{ enabled }` toggles visibility (the system `copy` item can't be hidden - only relabeled) and `label` overrides the English default. On iOS this goes through the same iOS 16+ edit-menu API as [`contextMenuItems`](#contextmenuitems), so it is ignored on earlier versions.

<PropInfo type="TextSelectionMenuConfig" default="{ copyAsMarkdown: { enabled: true }, copyImageUrl: { enabled: true } }" />

```ts
interface TextSelectionMenuConfig {
  copy?: { label?: string }; // system Copy: relabel only, cannot be hidden
  copyAsMarkdown?: { enabled?: boolean; label?: string };
  copyImageUrl?: {
    // shown when the selection contains images
    enabled?: boolean;
    label?: string; // single image
    pluralLabels?: TextSelectionMenuPluralLabels; // 2 or more images
  };
}

interface TextSelectionMenuPluralLabels {
  other: string; // required; every other category falls back to this
  zero?: string;
  one?: string;
  two?: string;
  few?: string;
  many?: string;
}
```

In each plural form, the `{count}` token is replaced with the number of selected images. A selection containing exactly one image always uses the singular `label`, never a plural form - `pluralLabels` starts at two.

<LivePreview src={SelectionMenuConfigSrc} unavailable unavailableReason={<>iOS, Android, and macOS only - it customizes the native selection menu.</>} />

:::note
With `flavor="github"`, `selection.start` / `selection.end` in menu callbacks are relative to the text segment the selection is in, not the full Markdown string. With `flavor="commonmark"` they are absolute within the full rendered text.
:::

### `accessibilityLabels`

Translations for every string spoken by VoiceOver (iOS) and TalkBack (Android): list items, table rows, math, and the iOS rotor. All fields are optional; omitted fields fall back to the English defaults. Placeholders (`{n}`, `{content}`, `{latex}`) are substituted natively at speak time and must be preserved in translations. See the [Accessibility guide](/user-experience/accessibility) for the full defaults table.

<PropInfo type="AccessibilityLabels" />

```ts
interface AccessibilityLabels {
  list?: {
    bulletPoint?: string;
    nestedBulletPoint?: string;
    orderedItem?: string; // {n} is the 1-based item number
    nestedOrderedItem?: string; // {n} is the 1-based item number
  };
  blockquote?: {
    quote?: string;
    nestedQuote?: string;
  };
  table?: {
    row?: string; // {n} is the 1-based row index, {content} the joined cell text
  };
  math?: {
    equation?: string; // {latex} is the equation source
  };
  rotor?: {
    // iOS only, Android has no rotor
    headings?: string;
    links?: string;
    images?: string;
  };
}
```

The package also exports the defaults themselves: `DEFAULT_ACCESSIBILITY_LABELS` (the full English object, the natural thing to seed a translation table from) and `resolveAccessibilityLabels(labels)`, which merges a partial override onto them and returns a `ResolvedAccessibilityLabels`.

<LivePreview src={AccessibilityLabelsSrc} unavailable unavailableReason={<>iOS and Android only - it translates VoiceOver / TalkBack announcements.</>} />

### `numberOfLines`

Clamps the rendered Markdown to a maximum number of lines, truncating with an ellipsis (see [`ellipsizeMode`](#ellipsizemode)) when it overflows. `0` (the default) means unlimited. Mirrors the prop of the same name on React Native's core [`Text`](https://reactnative.dev/docs/text#numberoflines), and is meant for previews such as chat-list rows or reply quotes. The clamp is applied to the measurement pass as well as the rendered view, so measured and rendered heights stay in sync.

:::note
CommonMark only. Under [`flavor="github"`](#flavor) the content is laid out as independent block segments that cannot honor a document-wide line cap, so the prop is ignored.
:::

:::caution
**On Android a clamped view is neither selectable nor tappable.** While `numberOfLines > 0`, text selection and link taps are off regardless of [`selectable`](#selectable). Android draws the truncation ellipsis only through `StaticLayout`, but enabling selection or a link movement method promotes the text to `DynamicLayout`, which has no `maxLines` support - React Native's own `Text` behaves the same way. Both are restored once the clamp is removed, and iOS keeps selection and links while clamped.
:::

<PropInfo type="number" default="0" />

<LivePreview src={NumberOfLinesSrc} unavailable unavailableReason={<>iOS, Android, and macOS only - the web build does not clamp.</>} />

### `ellipsizeMode`

Where the ellipsis is placed when text is truncated by [`numberOfLines`](#numberoflines). Only takes effect when `numberOfLines` is set, and ignored under [`flavor="github"`](#flavor) for the same reason. Mirrors the prop of the same name on React Native's core [`Text`](https://reactnative.dev/docs/text#ellipsizemode).

<PropInfo type="'head' | 'middle' | 'tail' | 'clip'" default="'tail'" />

<LivePreview src={EllipsizeModeSrc} unavailable unavailableReason={<>iOS, Android, and macOS only - the web build does not clamp.</>} />

- `'head'`: ellipsis at the start (`...d of the text`).
- `'middle'`: ellipsis in the middle (`start...end`).
- `'tail'` **(default)**: ellipsis at the end (`start of the...`).
- `'clip'`: truncate at the line boundary with no ellipsis glyph.

:::caution
`'head'` and `'middle'` are single-line truncation modes - they only place the ellipsis as described when `numberOfLines` is `1`. Past one line Android falls back to tail-style truncation (only `TruncateAt.END` works there) and iOS is likewise unreliable, so use `'tail'` or `'clip'` for multi-line clamps. Same limitation as React Native's `Text`.
:::

### `textBreakStrategy` <AndroidBadge /> {#textbreakstrategy}

Controls how Android breaks lines within paragraphs. Mirrors the prop of the same name on React Native's core `Text`. Requires API 23+.

<PropInfo type="'simple' | 'highQuality' | 'balanced'" default="'highQuality'" />

<LivePreview src={TextBreakStrategySrc} unavailable unavailableReason={<>Android only - line-break strategy has no effect on the web build.</>} />

- `'simple'`: greedy, no hyphenation; cheapest.
- `'highQuality'` **(default)**: full paragraph optimization with hyphenation.
- `'balanced'`: balances line lengths across the paragraph; no hyphenation.

### `lineBreakStrategyIOS` <IosBadge /> {#linebreakstrategyios}

Controls iOS line-breaking refinements. Mirrors the prop of the same name on React Native's core `Text` and maps to `NSParagraphStyle.lineBreakStrategy`. Requires iOS 14+.

<PropInfo type="'none' | 'standard' | 'hangul-word' | 'push-out'" default="'none'" />

<LivePreview src={LineBreakStrategyIOSSrc} unavailable unavailableReason={<>iOS only - line-break strategy has no effect on the web build.</>} />

- `'none'` **(default)**: no additional strategy.
- `'standard'`: the system's standard refinements.
- `'hangul-word'`: prefers breaking at Korean word boundaries.
- `'push-out'`: avoids orphaned short trailing lines by pushing words to the next line.

### `writingDirection` <IosBadge /> {#writingdirection}

Paragraph writing direction.

:::important
Android resolves direction per paragraph via the platform Bidi heuristic (`TEXT_DIRECTION_FIRST_STRONG`) and is unaffected by this prop.
:::

<PropInfo type="'auto' | 'ltr' | 'rtl' | 'first-strong'" default="'first-strong'" />

<LivePreview src={WritingDirectionSrc} unavailable unavailableReason={<>iOS only - Android resolves direction automatically; use <code>dir</code> on web.</>} />

- `'first-strong'` **(default)**: library extension. Each paragraph resolves its base direction from its first strong directional character, so mixed Arabic/Hebrew/English documents render correctly out of the box. Neutral-only paragraphs fall back to the view's Yoga-resolved layout direction.
- `'auto'`: React Native parity. TextKit follows the app's `userInterfaceLayoutDirection`; mixed-direction paragraphs do not auto-resolve.
- `'ltr'` / `'rtl'`: force the base direction on every paragraph. Code blocks always render left-to-right regardless of this prop.

:::note
See [RTL support](/user-experience/rtl) for the full behavior information.
:::

### `dir` <WebBadge /> {#dir}

Sets the text direction on the root container on web. The web renderers use CSS logical properties, so this flips blockquote borders, list indentation, and other directional layout automatically. It is the web counterpart to [`writingDirection`](#writingdirection) (iOS) - on iOS and Android it is a no-op, as those platforms resolve direction per paragraph.

<PropInfo type="'ltr' | 'rtl' | 'auto'" />

<LivePreview src={DirSrc} />

## Events

Callback props fired in response to native interactions. Each has a live playground like the props above.

### `onLinkPress`

Callback fired when a link is tapped.

<PropInfo type="(event: LinkPressEvent) => void" />

```ts
interface LinkPressEvent {
  url: string; // the tapped link's URL
}
```

<LivePreview src={OnLinkPressSrc} />

### `onLinkLongPress`

Callback fired when a link is long-pressed. On iOS, providing this handler automatically disables the system link preview (see [`enableLinkPreview`](#enablelinkpreview)). On web, it maps to the `contextmenu` (right-click) event. On iOS 17+ a link that matches a [`linkContextMenuItems`](#linkcontextmenuitems) pattern shows that menu instead of calling this handler.

<PropInfo type="(event: LinkLongPressEvent) => void" />

```ts
interface LinkLongPressEvent {
  url: string; // the long-pressed link's URL
}
```

<LivePreview src={OnLinkLongPressSrc} />

### `onImagePress`

Callback fired when a rendered image is tapped or clicked. Read the image URL from `event.url` and its Markdown alt text from `event.altText` (`""` when the image has no alt text) - use it to open a lightbox or full-screen viewer.

Fires for block and inline images, including images inside headings, lists, blockquotes, and GFM table cells. An image that is also a link (`[![alt](img)](dest)`) keeps link behavior and fires [`onLinkPress`](#onlinkpress) instead, so a single tap never fires both.

Setting this callback makes images interactive; leaving it unset keeps the default tap, text-selection, and long-press behavior unchanged. On web the image becomes focusable, exposes a button role for screen readers, and can be activated with Enter/Space, while the browser's right-click menu is preserved.

<PropInfo type="(event: ImagePressEvent) => void" />

```ts
interface ImagePressEvent {
  url: string; // the pressed image's URL
  altText: string; // the image's Markdown alt text ("" if none)
}
```

<LivePreview src={OnImagePressSrc} />

### `onTaskListItemPress`

Callback fired when a task list checkbox is tapped. The checkbox is toggled natively. Only fires when `flavor="github"`.

<PropInfo type="(event: TaskListItemPressEvent) => void" />

```ts
interface TaskListItemPressEvent {
  index: number; // 0-based item index
  checked: boolean; // checked state after toggling
  text: string; // the item's text
}
```

<LivePreview src={OnTaskListItemPressSrc} />

### `onCopyPress`

Callback fired when code is copied from a fenced code block - via the header copy button, the long-press **Copy** action, or the VoiceOver copy action. Does not fire for **Copy as Markdown**. Only fires when `flavor="github"`.

<PropInfo type="(event: CopyPressEvent) => void" />

```ts
interface CopyPressEvent {
  code: string; // the copied code
  language: string; // fence language ("" if none)
}
```

<LivePreview src={OnCopyPressSrc} unavailable unavailableReason={<>iOS, Android, and macOS only - copying from a code block is a native interaction, and the web build renders code blocks without a copy affordance.</>} />

### `onCodeBlockPress`

Callback fired when a fenced code block is tapped or clicked anywhere in its body. Use it for actions like opening the code in a viewer or copying it yourself.

Setting this prop is what arms the block for taps; leaving it unset keeps the block inert, with text selection, the header copy button, and the long-press menu unchanged. A tap never fires while text is being selected - selection still starts on long press. Works in both flavors: `flavor="github"` fires on the container-based code block, `flavor="commonmark"` on the code-block region inside the single text view. On web the block becomes a clickable, keyboard-activatable element with a button role.

<PropInfo type="(event: CodeBlockPressEvent) => void" />

```ts
interface CodeBlockPressEvent {
  code: string; // the block's source
  language: string; // fence language ("" if none)
}
```

<LivePreview src={OnCodeBlockPressSrc} />

### `onLatexError`

Callback fired when a math expression cannot be parsed or rendered by the LaTeX engine. The expression still renders - it falls back to showing its raw source rather than crashing - so this is a reporting hook, not a recovery one. Requires [`md4cFlags.latexMath`](#latexmath) (on by default).

Fires **at most once per distinct failing expression** per component instance. The de-duplication is keyed by `displayMode` + `source` and its cache survives `markdown` changes, so streaming content reports each failure once instead of on every update.

:::caution
De-duplication is per component **instance**. A remount - navigation, a changed React `key`, or list recycling - produces a fresh instance with no memory of prior reports, which fires again for the same expressions. De-duplicate on your side (by `source`) if you aggregate app-wide. See [Handling render errors](/rich-text-formatting/latex-math#handling-render-errors).
:::

<PropInfo type="(event: LatexErrorEvent) => void" />

```ts
interface LatexErrorEvent {
  source: string; // raw LaTeX, without $ / $$ delimiters
  message?: string; // engine error message, when it gives one
  displayMode: boolean; // false for inline $...$, true for block $$...$$
}
```

<LivePreview src={OnLatexErrorSrc} unavailable unavailableReason={<>iOS and Android only - the web build renders math with KaTeX and does not report failures through this callback.</>} />

## See also

- [Element structure](/react-native/api-reference/element-structure) - every supported element, its syntax, block vs. inline categorization, and nesting behavior.
- [Style properties](/react-native/api-reference/style-properties) - all styleable properties, including a [Dark mode](/react-native/api-reference/style-properties#dark-mode) recipe with `useColorScheme()`.
- [Copy options](/user-experience/copy-options) - smart copy, copy as Markdown, and copy image URL.
- [Link pills](/react-native/guides/link-pills) - presenting links as rounded chips with an icon and label.
- [Link menus](/react-native/guides/link-menus) - what a long press on a link does, and custom menus per URL pattern.
- [Accessibility](/user-experience/accessibility) - VoiceOver and TalkBack support, custom rotors, and semantic traits.
- [Testing with Jest](/react-native/guides/testing) - the shipped Jest mock for rendering and asserting on the components in tests.
- [RTL support](/user-experience/rtl) - right-to-left languages and per-element RTL behavior.
