---
sidebar_label: EnrichedMarkdownText
sidebar_position: 1
---

import InteractiveExample from '@site/src/components/InteractiveExample';
import LivePreview from '@site/src/components/LivePreview';
import FirstText from '@site/src/examples/react-native/basics/your-first-project/FirstText';
import FirstTextSrc from '!!raw-loader!@site/src/examples/react-native/basics/your-first-project/FirstText';

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
import OnLinkPressSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/OnLinkPress';
import OnLinkLongPressSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/OnLinkLongPress';
import OnTaskListItemPressSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/OnTaskListItemPress';
import EnableTaskListItemToggleSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/EnableTaskListItemToggle';
import OnCopyPressSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text/OnCopyPress';
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

`EnrichedMarkdownText` accepts every prop below. It also forwards the standard React Native [`View`](https://reactnative.dev/docs/view#props) props - such as `testID`, `onLayout`, `pointerEvents`, `hitSlop`, and the `accessibility*` props - to the underlying native view. The one exception is `style`: use [`containerStyle`](#containerstyle) instead. It maps to the wrapper view's `style`, and is renamed so it is not mistaken for styling the Markdown text - that is [`markdownStyle`](#markdownstyle).

:::note
Each prop has a live playground below - edit the code and try it. Props marked with a <IosBadge />, <AndroidBadge />, or <WebBadge /> badge only take effect on that platform.
:::

### `markdown`

The Markdown content to render. Depending on the [flavor](/react-native/api-reference/enriched-markdown-text#flavor), [md4c flags](/react-native/api-reference/enriched-markdown-text#md4cflags), etc., this supports different syntax elements. To learn more, go to the [Feature support page](/introduction/supported-features).

<PropInfo type="string" required />

<LivePreview src={MarkdownSrc} />

### `markdownStyle`

Style configuration for Markdown elements. See the [Style properties reference](/react-native/api-reference/style-properties) for the full list of styleable properties.

<PropInfo type="MarkdownStyle" default="{}" />

<LivePreview src={MarkdownStyleSrc} />

### `containerStyle`

Style for the view that wraps the rendered Markdown. `ViewStyle` and `TextStyle` are React Native's own style types: in practice you use the [`ViewStyle`](https://reactnative.dev/docs/view-style-props) layout and appearance properties here: `padding`, `margin`, `backgroundColor`, `borderRadius`, `borderWidth`, and the [flexbox](https://reactnative.dev/docs/flexbox) props. [`TextStyle`](https://reactnative.dev/docs/text-style-props) is accepted for parity, but to style the text itself (headings, links, code, and other elements) use [`markdownStyle`](#markdownstyle) instead.

:::note
`containerStyle` is React Native's regular `style` prop, renamed. It is handed straight to the wrapper `<View>`, so `ViewStyle` values (`padding`, `margin`, `backgroundColor`, the flexbox props) behave exactly as on any React Native view. It is renamed because the renderer is text-like: a prop called `style` would imply it styles the Markdown text, but the text is styled per element through [`markdownStyle`](#markdownstyle). `containerStyle` styles only the box around it.
:::

<PropInfo type="ViewStyle | TextStyle" />

<LivePreview src={ContainerStyleSrc} />

### `flavor`

Markdown flavor. `'commonmark'` (default) renders the whole document as a single text view. `'github'` splits the AST into segments and enables GitHub Flavored Markdown features: tables and block-style fenced code blocks (with a header bar, language label, and copy button). Text selection cannot span across segments.

For exactly which syntax each flavor parses and renders, and which elements are GitHub-only, see the [Feature support](/introduction/supported-features) matrix and the [Element structure](/react-native/api-reference/element-structure) reference. Extra inline syntax (underline, highlight, super/subscript, math) is enabled separately through [`md4cFlags`](#md4cflags), independent of the flavor.

<PropInfo type="'commonmark' | 'github'" default="'commonmark'" />

<LivePreview src={FlavorSrc} unavailable unavailableReason={<>iOS and Android only - the web build always parses GitHub extensions, so there is no flavor switch.</>} />

### `md4cFlags`

Toggles for md4c's parser extensions; each opts a piece of extra inline syntax in or out. Pass only the flags you want to change; the rest keep their defaults below. Where a flag enables a new inline element, tune its appearance through the matching [style property](/react-native/api-reference/style-properties).

<PropInfo type="Md4cFlags" default="{ underline: false, superscript: false, subscript: false, highlight: false, latexMath: true, hardSoftBreaks: false }" />

#### `underline`

When `true`, treats `_text_` as underline instead of emphasis. With it on, only `*text*` produces italic emphasis.

<PropInfo type="boolean" default="false" />

<LivePreview src={Md4cUnderlineSrc} />

#### `superscript`

When `true`, parses `^text^` as superscript.

<PropInfo type="boolean" default="false" />

<LivePreview src={Md4cSuperscriptSrc} />

#### `subscript`

When `true`, parses `~text~` as subscript. When disabled, single and double tildes stay as strikethrough markers instead.

<PropInfo type="boolean" default="false" />

<LivePreview src={Md4cSubscriptSrc} />

#### `highlight`

When `true`, parses `==text==` as highlighted spans. When disabled, double equals signs are treated as plain text.

<PropInfo type="boolean" default="false" />

<LivePreview src={Md4cHighlightSrc} />

#### `latexMath`

When `true`, parses `$...$` as inline math and `$$...$$` as display math. Rendering uses KaTeX.

<PropInfo type="boolean" default="true" />

<LivePreview src={Md4cLatexMathSrc} />

#### `hardSoftBreaks`

When `true`, treats single newlines (soft breaks) as hard breaks, rendering them as visible line breaks instead of collapsing them into spaces. See [Line breaks](/react-native/api-reference/element-structure) for details.

<PropInfo type="boolean" default="false" />

<LivePreview src={Md4cHardSoftBreaksSrc} />

### `enableTaskListItemToggle`

Controls whether tapping a task list checkbox toggles its checked state. When `false`, the checkbox renders its Markdown state read-only and the tap is **fully inert**; no visual toggle and `onTaskListItemPress` does not fire. Text selection and links in the same row are unaffected.

<PropInfo type="boolean" default="true" />

<LivePreview src={EnableTaskListItemToggleSrc} />

### `enableLinkPreview` <IosBadge /> {#enablelinkpreview}

Controls the native link preview on long press. Defaults to `true`, but automatically becomes `false` when `onLinkLongPress` is provided. Set it explicitly to override the automatic behavior.

<PropInfo type="boolean" default="true" />

<LivePreview src={EnableLinkPreviewSrc} unavailable unavailableReason={<>iOS only - the system link preview is an iOS feature.</>} />

### `selectable`

Whether text can be selected. For example on web, `false` applies `user-select: none`.

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

When `true`, newly appended content fades in during streaming updates. Only the tail (new characters beyond the previous content) is animated. Recommended for LLM streaming use cases.

<PropInfo type="boolean" default="false" />

<LivePreview src={StreamingAnimationSrc} unavailable unavailableReason={<>iOS and Android only - the fade-in animation is native.</>} />

### `streamingConfig`

Fine-grained control over how incomplete tables and fenced code blocks are handled while streaming with `flavor="github"`. Only effective when `streamingAnimation` is `true`.

<PropInfo type="{ tableMode?: 'progressive' | 'hidden', codeBlockMode?: 'progressive' | 'hidden' }" default="{ tableMode: 'progressive', codeBlockMode: 'progressive' }" />

<LivePreview src={StreamingConfigSrc} unavailable unavailableReason={<>iOS and Android only - streaming block handling is native.</>} />

- `tableMode`
  - `'progressive'` **(default)** renders the table row-by-row as content arrives (incomplete trailing rows are trimmed);
  - `'hidden'` withholds the table until it is complete.
- `codeBlockMode`
  - `'progressive'` **(default)** streams the code in with a visible but non-interactive header and defers syntax highlighting until the closing fence arrives;
  - `'hidden'` withholds the block until it is complete.

### `spoilerOverlay`

Controls how spoiler text (`||hidden text||`) is displayed before being revealed. Both modes support tap-to-reveal.

<PropInfo type="'particles' | 'solid'" default="'particles'" />

<LivePreview src={SpoilerOverlaySrc} unavailable unavailableReason={<>iOS and Android only - the spoiler overlay is not rendered by the web build.</>} />

- **`'particles'`**: animated particle overlay (CAEmitterLayer on iOS, Choreographer-driven Canvas particles on Android).
- **`'solid'`**: opaque rectangle covering the text (Discord-style).

### `imageRequestHeaders`

HTTP headers attached to remote image requests, e.g. a `Referer` required by CDN hotlink protection or an `Authorization` token. Headers participate in image cache identity, so the same URL requested with different headers is fetched and cached separately.

<PropInfo type="Record<string, string>" />

<LivePreview src={ImageRequestHeadersSrc} unavailable unavailableReason={<>Not supported on web - browsers don't allow custom headers on <code>&lt;img&gt;</code> requests.</>} />

### `contextMenuItems`

Custom items to add to the text selection context menu. Items appear before the system actions and are hidden when `visible: false`. On iOS this requires iOS 16+; on earlier versions the prop is ignored.

<PropInfo type="ContextMenuItem[]" />

```ts
interface ContextMenuItem {
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

<LivePreview src={ContextMenuItemsSrc} unavailable unavailableReason={<>iOS and Android only - it customizes the native selection menu.</>} />

### `selectionMenuConfig`

Controls the built-in actions in the native text selection menu (and the table/math copy menus) and lets you localize their labels. Custom app actions are controlled separately with `contextMenuItems`. Each item takes an object: `{ enabled }` toggles visibility (the system `copy` item can't be hidden - only relabeled) and `label` overrides the English default.

<PropInfo type="SelectionMenuConfig" default="{}" />

```ts
interface SelectionMenuConfig {
  copy?: { label?: string }; // system Copy: relabel only, cannot be hidden
  copyAsMarkdown?: { enabled?: boolean; label?: string };
  copyImageUrl?: { // shown when the selection contains images
    enabled?: boolean;
    label?: string; // single image
    pluralLabels?: SelectionMenuPluralLabels; // multiple images
  };
}

interface SelectionMenuPluralLabels {
  other: string; // required; every other category falls back to this
  zero?: string;
  one?: string;
  two?: string;
  few?: string;
  many?: string;
}
```

In each plural form, the `{count}` token is replaced with the number of selected images.

<LivePreview src={SelectionMenuConfigSrc} unavailable unavailableReason={<>iOS, Android, and macOS only - it customizes the native selection menu.</>} />

:::note
With `flavor="github"`, `selection.start` / `selection.end` in menu callbacks are relative to the text segment the selection is in, not the full Markdown string. With `flavor="commonmark"` they are absolute within the full rendered text.
:::

### `accessibilityLabels`

Translations for every string spoken by VoiceOver (iOS) and TalkBack (Android): list items, table rows, math, and the iOS rotor. All fields are optional; omitted fields fall back to the English defaults. Placeholders (`{n}`, `{content}`, `{latex}`) are substituted natively at speak time and must be preserved in translations. See the [Accessibility guide](/misc/accessibility) for the full defaults table.

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
    row?: string; // {n} is the row index, {content} the joined cell text
  };
  math?: {
    equation?: string; // {latex} is the equation source
  };
  rotor?: { // iOS only, Android has no rotor
    headings?: string;
    links?: string;
    images?: string;
  };
}
```

Every field is optional; see the [Accessibility guide](/misc/accessibility) for each field's English default.

<LivePreview src={AccessibilityLabelsSrc} unavailable unavailableReason={<>iOS and Android only - it translates VoiceOver / TalkBack announcements.</>} />

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

Paragraph writing direction. iOS only.

:::important
Android resolves direction per paragraph via the platform Bidi heuristic (`TEXT_DIRECTION_FIRST_STRONG`) and is unaffected by this prop.
:::

<PropInfo type="'auto' | 'ltr' | 'rtl' | 'first-strong'" default="'first-strong'" />

<LivePreview src={WritingDirectionSrc} unavailable unavailableReason={<>iOS only - Android resolves direction automatically; use <code>dir</code> on web.</>} />

- `'first-strong'` **(default)**: library extension. Each paragraph resolves its base direction from its first strong directional character, so mixed Arabic/Hebrew/English documents render correctly out of the box. Neutral-only paragraphs fall back to the view's Yoga-resolved layout direction.
- `'auto'`: React Native parity. TextKit follows the app's `userInterfaceLayoutDirection`; mixed-direction paragraphs do not auto-resolve.
- `'ltr'` / `'rtl'`: force the base direction on every paragraph. Code blocks always render left-to-right regardless of this prop.

:::note
See [RTL support](/misc/rtl) for the full behavior information.
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

Callback fired when a link is long-pressed. On iOS, providing this handler automatically disables the system link preview (see [`enableLinkPreview`](#enablelinkpreview)). On web, it maps to the `contextmenu` (right-click) event.

<PropInfo type="(event: LinkLongPressEvent) => void" />

```ts
interface LinkLongPressEvent {
  url: string; // the long-pressed link's URL
}
```

<LivePreview src={OnLinkLongPressSrc} />

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

## Try it yourself

<InteractiveExample src={FirstTextSrc} component={FirstText} />

## See also

- [Element structure](/react-native/api-reference/element-structure) - every supported element, its syntax, block vs. inline categorization, and nesting behavior.
- [Style properties](/react-native/api-reference/style-properties) - all styleable properties, including a [Dark mode](/react-native/api-reference/style-properties#dark-mode) recipe with `useColorScheme()`.
- [Copy options](/misc/copy-options) - smart copy, copy as Markdown, and copy image URL.
- [Accessibility](/misc/accessibility) - VoiceOver and TalkBack support, custom rotors, and semantic traits.
- [RTL support](/misc/rtl) - right-to-left languages and per-element RTL behavior.
