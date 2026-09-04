---
sidebar_label: EnrichedMarkdownTextInput
sidebar_position: 2
---

import InteractiveExample from '@site/src/components/InteractiveExample';
import LivePreview from '@site/src/components/LivePreview';
import FirstEditorSrc from '!!raw-loader!@site/src/examples/react-native/basics/your-first-project/FirstEditor';

import DefaultValueSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/DefaultValue';
import PlaceholderSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/Placeholder';
import PlaceholderTextColorSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/PlaceholderTextColor';
import EditableSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/Editable';
import AutoFocusSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/AutoFocus';
import ScrollEnabledSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/ScrollEnabled';
import MultilineSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/Multiline';
import AutoCapitalizeSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/AutoCapitalize';
import CursorColorSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/CursorColor';
import SelectionColorSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/SelectionColor';
import StyleSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/Style';
import MarkdownStyleSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/MarkdownStyle';
import LinkRegexSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/LinkRegex';
import MentionsSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/Mentions';
import ContextMenuItemsSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/ContextMenuItems';
import SelectionMenuConfigSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/SelectionMenuConfig';
import FormatMenuConfigSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/FormatMenuConfig';
import WritingDirectionSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/WritingDirection';
import OnChangeTextSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/OnChangeText';
import OnChangeMarkdownSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/OnChangeMarkdown';
import OnChangeSelectionSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/OnChangeSelection';
import OnChangeStateSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/OnChangeState';
import OnKeyPressSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/OnKeyPress';
import OnCaretRectChangeSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/OnCaretRectChange';
import OnLinkDetectedSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/OnLinkDetected';
import FocusBlurSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/FocusBlur';
import SetValueSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/SetValue';
import GetMarkdownSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/GetMarkdown';
import InsertTextSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/InsertText';
import CopyToClipboardSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/CopyToClipboard';
import SetSelectionSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/SetSelection';
import CaretSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/Caret';
import ToggleBoldSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/ToggleBold';
import ToggleItalicSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/ToggleItalic';
import ToggleUnderlineSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/ToggleUnderline';
import ToggleStrikethroughSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/ToggleStrikethrough';
import ToggleSpoilerSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/ToggleSpoiler';
import ToggleHeadingSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/ToggleHeading';
import ToggleUnorderedListSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/ToggleUnorderedList';
import ToggleOrderedListSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/ToggleOrderedList';
import IndentOutdentSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/IndentOutdent';
import SetLinkSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/SetLink';
import InsertLinkSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/InsertLink';
import RemoveLinkSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/RemoveLink';
import StartMentionSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/enriched-markdown-text-input/StartMention';

# EnrichedMarkdownTextInput

export const soon = (
<>The editable input is not yet available on web - the code is shown for reference.</>
);

`EnrichedMarkdownTextInput` is a native, [WYSIWYG](https://en.wikipedia.org/wiki/WYSIWYG) rich text editor whose content is Markdown: the user sees formatted text as they type - bold looks bold, not `**bold**` - while the value is stored as Markdown. Seed it with a Markdown string and read the edited content back as Markdown whenever you need it. Markdown is the source of truth on both sides of the edit, so content round-trips cleanly in and out. It renders with the platform's native text stack (`UITextView` on iOS, `EditText` on Android), and is an **uncontrolled** input - it does not hold its value in React state or props, but talks directly to the underlying native component, which keeps it fast and simple.

```tsx
import { useRef, useState } from 'react';
import { View, Button, StyleSheet } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
  type StyleState,
} from 'react-native-enriched-markdown';

export default function App() {
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [state, setState] = useState<StyleState | null>(null);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownTextInput
        ref={ref}
        placeholder="Type here..."
        onChangeState={setState}
        style={styles.input}
      />
      <Button
        title={state?.bold.isActive ? 'Unbold' : 'Bold'}
        color={state?.bold.isActive ? 'green' : 'gray'}
        onPress={() => ref.current?.toggleBold()}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 8 },
  input: {
    fontSize: 18,
    padding: 12,
    minHeight: 96,
    backgroundColor: '#eef0ff',
  },
});
```

The example above shows the two patterns you will use everywhere:

- **Drive formatting through the ref.** Call methods like [`toggleBold()`](#ref-methods) to apply a style to the current selection or cursor.
- **Read active styles from [`onChangeState`](#onchangestate).** It reports which styles are active at the cursor, so your toolbar can highlight the right buttons.

## Props

`EnrichedMarkdownTextInput` accepts every prop below. It also forwards the standard React Native [`View`](https://reactnative.dev/docs/view#props) props - such as `testID`, `onLayout`, `pointerEvents`, and the `accessibility*` props - to the underlying native view.

:::note
Props marked with a <IosBadge /> or <AndroidBadge /> badge only take effect on that platform. Unlike [`EnrichedMarkdownText`](/react-native/api-reference/enriched-markdown-text), the editable input is **not yet available on web**, so each example shows its source now; a runnable live preview will follow once web support lands.
:::

### `defaultValue`

Initial Markdown content. It is parsed and formatting is applied on mount.

<PropInfo type="string" />

:::important
Following React Native `TextInput` semantics, `defaultValue` is read **once, at mount** - later changes to it are ignored. To replace the content imperatively afterwards, call [`setValue`](#setvaluemarkdown-string) on the ref.
:::

<LivePreview src={DefaultValueSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `placeholder`

Text shown while the input is empty.

<PropInfo type="string" />

:::important
The placeholder is plain text, not Markdown. Unlike [`defaultValue`](#defaultvalue), Markdown syntax here is shown literally - `**bold**` appears as those raw characters, never as bold text. It is drawn as a plain label, so it also ignores [`markdownStyle`](#markdownstyle); use [`placeholderTextColor`](#placeholdertextcolor) and the base `style` font to style it.
:::

<LivePreview src={PlaceholderSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `placeholderTextColor`

Color of the placeholder text.

<PropInfo type="ColorValue" typeHref="https://reactnative.dev/docs/colors" />

<LivePreview src={PlaceholderTextColorSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `editable`

Whether the input can be edited. When `false`, the content is still selectable but cannot be changed.

<PropInfo type="boolean" default="true" />

<LivePreview src={EditableSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `autoFocus`

Whether the input focuses itself on mount.

<PropInfo type="boolean" default="false" />

<LivePreview src={AutoFocusSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `scrollEnabled`

Whether the input scrolls its own content when it overflows. Set to `false` when the input lives inside an outer `ScrollView` and you size it to its content; pair it with [`onCaretRectChange`](#oncaretrectchange) to keep the caret visible.

<PropInfo type="boolean" default="true" />

<LivePreview src={ScrollEnabledSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `multiline`

Whether the input accepts multiple lines.

<PropInfo type="boolean" default="true" />

<LivePreview src={MultilineSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `autoCapitalize`

Auto-capitalization behavior, mirroring the [prop of the same name](https://reactnative.dev/docs/textinput#autocapitalize) on React Native's `TextInput`.

<PropInfo type="'none' | 'sentences' | 'words' | 'characters'" default="'sentences'" />

<LivePreview src={AutoCapitalizeSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `cursorColor`

Color of the text caret.

<PropInfo type="ColorValue" typeHref="https://reactnative.dev/docs/colors" />

:::caution
On **Android** and **macOS**, `cursorColor` (the caret) and [`selectionColor`](#selectioncolor) (the selection highlight) are independent - set them to whatever two colors you like.

On **iOS** there is no separate caret color: both props map to the text view's single `tintColor`, which UIKit uses for the caret, selection, and handles together. If you set them to two different colors, **`selectionColor` wins** (it is applied last) - the caret, selection, and handles all take the `selectionColor`, and `cursorColor` has no visible effect. So on iOS, style the caret through `selectionColor` and leave `cursorColor` unset.
:::

<LivePreview src={CursorColorSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `selectionColor`

Color of the text selection highlight. On Android and macOS it affects only the selection background. On iOS it shares a single tint with the caret and selection handles, so it also sets the caret color and takes precedence over [`cursorColor`](#cursorcolor).

<PropInfo type="ColorValue" typeHref="https://reactnative.dev/docs/colors" />

<LivePreview src={SelectionColorSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `style`

Style for the input view. Accepts both [`ViewStyle`](https://reactnative.dev/docs/view-style-props) layout properties (`padding`, `margin`, `backgroundColor`, the [flexbox](https://reactnative.dev/docs/flexbox) props) and [`TextStyle`](https://reactnative.dev/docs/text-style-props) properties (`fontSize`, `color`, `fontFamily`, `lineHeight`), which set the base text appearance the Markdown styles build on.

<PropInfo type="ViewStyle | TextStyle" />

:::note
The input uses the regular `style` prop directly, just like a native `TextInput`: here `TextStyle` values (`fontSize`, `color`, ...) really do set the base text appearance, so the name is honest. The read-only [`EnrichedMarkdownText`](/react-native/api-reference/enriched-markdown-text) renames its equivalent to `containerStyle` instead, because there `style` would only affect the wrapper box, not the rendered text. To restyle the formatted elements (bold, links, headings, ...), use [`markdownStyle`](#markdownstyle).
:::

<LivePreview src={StyleSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `markdownStyle`

Overrides for how formatted text is painted inside the input. Its type, `MarkdownTextInputStyle`, is a subset of the renderer's `MarkdownStyle` - the editor styles inline formatting, links, spoilers, and headings. Every field is optional and falls back to a default that matches the read-only [`EnrichedMarkdownText`](/react-native/api-reference/enriched-markdown-text) renderer, so content looks the same in the editor and a rendered preview. See [Editor styles](/react-native/api-reference/style-properties#editor-styles) for the full list of styleable properties.

<PropInfo type="MarkdownTextInputStyle" default="{}" />

<LivePreview src={MarkdownStyleSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `linkRegex`

A custom [regular expression](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Regular_expressions) for [auto-link detection](#onlinkdetected): the input tests typed text against it and turns matches into Markdown links. Pass `null` to disable auto-link detection entirely, or omit the prop to use the built-in URL matcher.

<PropInfo type="RegExp | null" typeHref="https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/RegExp" default="built-in URL matcher" />

By default, URLs like `google.com`, `www.google.com`, and `https://google.com` are detected when followed by a space or newline. Bare domains and `www.` prefixes are normalized with `https://` (e.g. `google.com` becomes `[google.com](https://google.com)`).

:::note
When a manual link ([`setLink`](#setlinkurl-string) / [`insertLink`](#insertlinktext-string-url-string)) overlaps an auto-detected one, the manual link wins. Auto-link detection skips ranges that already contain a manual link.
:::

<LivePreview src={LinkRegexSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `mentionIndicators`

Trigger characters that start a mention flow (e.g. `['@', '#']`). Typing one begins a mention; the [mention events](#onstartmention) and [`insertMention`](#insertmentiondisplaytext-string-url-string) drive the suggestion UI.

<PropInfo type="string[]" default="[]" />

:::note
See the [Mentions guide](/rich-text-formatting/mentions) for the full setup: events, ref methods, and per-pattern styling with `markdownStyle.linkVariants`.
:::

<LivePreview src={MentionsSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `contextMenuItems`

Custom items added to the text selection context menu. They appear before the system actions and are hidden when `visible: false`. Available on iOS, Android, and macOS (iOS requires 16+; earlier versions ignore the prop).

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
    /** Active formatting styles at the time of the press. */
    styleState: StyleState;
  }) => void;
  /** When false, the item is not shown. Defaults to true. */
  visible?: boolean;
}
```

<LivePreview src={ContextMenuItemsSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `selectionMenuConfig`

Controls the built-in items in the text selection menu - the **Format** submenu and the **Copy as Markdown** action - and lets you localize their labels. Custom app actions are controlled separately with [`contextMenuItems`](#contextmenuitems). Each item takes `{ enabled, label }`: `enabled` toggles visibility and `label` overrides the English default. Available on iOS, Android, and macOS.

<PropInfo type="InputSelectionMenuConfig" default="{}" />

```ts
interface InputSelectionMenuConfig {
  /** The "Format" submenu. @default { enabled: true, label: "Format" } */
  format?: { enabled?: boolean; label?: string };
  /** "Copy as Markdown" action. @default { enabled: true, label: "Copy as Markdown" } */
  copyAsMarkdown?: { enabled?: boolean; label?: string };
}
```

:::note
System **Cut / Copy / Paste / Select All** come from the platform and are already localized by the device language - they are not exposed through this prop.
:::

<LivePreview src={SelectionMenuConfigSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `formatMenuConfig`

Controls which items appear inside the **Format** submenu, and each item's label. Only effective while `selectionMenuConfig.format` is enabled (the default). Same `{ enabled, label }` shape as above. Available on iOS, Android, and macOS.

<PropInfo type="FormatMenuConfig" default="{}" />

```ts
interface FormatMenuConfig {
  /** @default { enabled: true, label: "Bold" } */
  bold?: { enabled?: boolean; label?: string };
  /** @default { enabled: true, label: "Italic" } */
  italic?: { enabled?: boolean; label?: string };
  /** @default { enabled: true, label: "Underline" } */
  underline?: { enabled?: boolean; label?: string };
  /** @default { enabled: true, label: "Strikethrough" } */
  strikethrough?: { enabled?: boolean; label?: string };
  /** @default { enabled: true, label: "Spoiler" } */
  spoiler?: { enabled?: boolean; label?: string };
  /** @default { enabled: true, label: "Link" } */
  link?: { enabled?: boolean; label?: string };
}
```

<LivePreview src={FormatMenuConfigSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `writingDirection` <IosBadge /> {#writingdirection}

Paragraph writing direction. iOS only.

:::important
Android's `EditText` resolves direction per paragraph via the platform Bidi heuristic (`TEXT_DIRECTION_FIRST_STRONG`) and is unaffected by this prop.
:::

<PropInfo type="'auto' | 'ltr' | 'rtl' | 'first-strong'" default="'first-strong'" />

- `'first-strong'` **(default)**: library extension. Each paragraph resolves its base direction from its first strong directional character, so mixed Arabic/Hebrew/English content right-aligns correctly as you type. Neutral-only paragraphs fall back to the view's resolved layout direction. Mirrors Android.
- `'auto'`: React Native parity. TextKit follows the app's `userInterfaceLayoutDirection`; mixed-direction paragraphs do not auto-resolve.
- `'ltr'` / `'rtl'`: force the base direction on every paragraph.

:::note
The **placeholder** follows the host view's layout direction, not this prop. For an RTL placeholder, wrap the input in `<View style={{ direction: 'rtl' }}>` or set `I18nManager.forceRTL(true)`. See [RTL support](/misc/rtl) for the full behavior.
:::

<LivePreview src={WritingDirectionSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

## Events

Every event below is an optional callback prop. Content-reading events fire whenever the relevant part of the input changes.

### `onChangeText`

Fires when the plain text changes. Returns the text **without** Markdown syntax.

<PropInfo type="(text: string) => void" />

<LivePreview src={OnChangeTextSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `onChangeMarkdown`

Fires when the Markdown representation changes. Returns the full Markdown string.

<PropInfo type="(markdown: string) => void" />

:::note
Producing the Markdown means rebuilding the whole document into a Markdown string on every change, which is not free. Unlike the other events - cheap byproducts of editing that always fire - this serialization runs **only when you pass the callback**, so omit it unless you actually need the Markdown live.
:::

<LivePreview src={OnChangeMarkdownSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `onChangeSelection`

Fires when the selection changes. Useful when applying [links](#setlinkurl-string) to a range.

<PropInfo type="(selection: { start: number; end: number }) => void" />

<LivePreview src={OnChangeSelectionSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `onChangeState`

Fires when the active style state changes. Each style reports `isActive`; `heading` additionally carries the cursor paragraph's `level`, and the list styles their nesting `depth`.

<PropInfo type="(state: StyleState) => void" />

```ts
interface StyleState {
  bold: { isActive: boolean };
  italic: { isActive: boolean };
  underline: { isActive: boolean };
  strikethrough: { isActive: boolean };
  spoiler: { isActive: boolean };
  link: { isActive: boolean };
  // Heading level of the cursor's paragraph: 0 = none, 1-6 = H1-H6.
  heading: { isActive: boolean; level: number };
  // `depth` is the 0-based nesting level and is only meaningful while
  // `isActive` is true (it is 0 when the cursor is not in a list).
  unorderedList: { isActive: boolean; depth: number };
  orderedList: { isActive: boolean; depth: number };
}
```

<LivePreview src={OnChangeStateSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `onKeyPress`

Fires on every keystroke, **before** the change is applied - mirroring React Native `TextInput`'s `onKeyPress`. `nativeEvent.key` is the pressed character or a named key: `Backspace`, `Enter`, `Tab` (iOS additionally reports `Escape`).

<PropInfo type="(e: NativeSyntheticEvent<OnKeyPressEvent>) => void" />

```ts
interface OnKeyPressEvent {
  key: string; // the pressed character, or a named key: Backspace, Enter, Tab, Escape (iOS)
}
```

The event is a React Native [`NativeSyntheticEvent`](https://reactnative.dev/docs/textinput#onkeypress), so read the key from `e.nativeEvent.key` - the same shape as `TextInput`'s `onKeyPress`.

:::note
On Android, the key reported for soft-keyboard input can lag actual typing when autocomplete suggestions are involved. Paste operations do not fire this event.
:::

<LivePreview src={OnKeyPressSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `onCaretRectChange`

Fires when the caret's pixel position changes (typing, selection change, content reflow). The rect is relative to the input's top-left corner, in density-independent pixels. The native side diffs the rect before emitting, so redundant events are suppressed. For one-off queries, use [`getCaretRect`](#getcaretrect-promisecaretrect) instead.

<PropInfo type="(rect: CaretRect) => void" />

```ts
interface CaretRect {
  x: number;
  y: number;
  width: number;
  height: number;
}
```

<LivePreview src={OnCaretRectChangeSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `onLinkDetected`

Fires when [auto-link detection](#linkregex) turns typed text into a link. Fires only for **newly** detected links, not for ones that already existed and stayed unchanged.

<PropInfo type="(event: { text: string; url: string; start: number; end: number }) => void" />

<LivePreview src={OnLinkDetectedSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `onStartMention`

Fires when a new mention flow starts (an indicator from [`mentionIndicators`](#mentionindicators) is typed).

<PropInfo type="(event: { indicator: string }) => void" />

:::note
`onStartMention`, [`onChangeMention`](#onchangemention), and [`onEndMention`](#onendmention) are the events of the mention flow; the example below shows all three together. For general information about mentions - trigger setup, the suggestion UI, ref methods, and per-pattern styling - see the [Mentions guide](/rich-text-formatting/mentions).
:::

<LivePreview src={MentionsSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `onChangeMention`

Fires on every keystroke while a mention flow is active - use the running `text` to filter your suggestion list.

<PropInfo type="(event: { indicator: string; text: string }) => void" />

Part of the same flow - see the [mention example under `onStartMention`](#onstartmention).

### `onEndMention`

Fires when the active mention flow ends (a selection is inserted, or the token is dismissed).

<PropInfo type="(event: { indicator: string }) => void" />

Part of the same flow - see the [mention example under `onStartMention`](#onstartmention).

### `onFocus`

Fires when the input gains focus.

<PropInfo type="() => void" />

<LivePreview src={FocusBlurSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `onBlur`

Fires when the input loses focus.

<PropInfo type="() => void" />

The [`onFocus` example](#onfocus) wires up both callbacks.

:::note
The input registers with React Native's text-input focus tracking (`TextInput.State`), so blur also happens through the platform's standard keyboard-dismiss paths: taps outside the input inside a `ScrollView` (per its [`keyboardShouldPersistTaps`](https://reactnative.dev/docs/scrollview#keyboardshouldpersisttaps)) and [`Keyboard.dismiss()`](https://reactnative.dev/docs/keyboard#dismiss).
:::

## Ref methods

All methods are called imperatively on a ref typed as `EnrichedMarkdownTextInputInstance`:

```tsx
const ref = useRef<EnrichedMarkdownTextInputInstance>(null);
// ...
ref.current?.toggleBold();
```

The instance also exposes the standard React Native host measurement methods (`measure`, `measureInWindow`, `measureLayout`).

:::note
The inline `toggle*` methods act on the **current selection**, or - when nothing is selected - queue the style so it applies to the next characters typed. The block methods (`toggleHeading`, list methods) act on the **whole paragraph** the cursor touches.
:::

### `focus()`

Focuses the input.

<LivePreview src={FocusBlurSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `blur()`

Blurs the input. The [`focus()` example](#focus) above wires up both methods.

### `setValue(markdown: string)`

Replaces the entire content by parsing `markdown` and applying its formatting. This is how you set content after mount (`defaultValue` is only read once).

<LivePreview src={SetValueSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `getMarkdown(): Promise<string>`

Returns the input's current content as a Markdown string. The result is a promise because the content is read from the native side.

<LivePreview src={GetMarkdownSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `insertText(text: string)`

Parses `text` as Markdown and inserts it at the cursor, replacing the selection if there is one. Leading and trailing newlines are preserved, so wrap block content in newlines to keep it on its own lines - `insertText('\n- item\n')` in the middle of `test` yields `te`, a `- item` bullet, and `st` on separate lines. An empty string is a no-op.

<LivePreview src={InsertTextSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `copyToClipboard()`

Copies the full content to the system clipboard, as if the user selected all and pressed **Copy**. The selection is left unchanged, and calling it on an empty input is a no-op.

:::note
On iOS and macOS the clipboard receives both plain text and a private Markdown pasteboard type, so pasting back into an `EnrichedMarkdownTextInput` restores the formatting; external apps receive plain text only. On Android the clipboard receives plain text only.
:::

<LivePreview src={CopyToClipboardSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `setSelection(start: number, end: number)`

Sets the selection range.

<LivePreview src={SetSelectionSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `getCaretRect(): Promise<CaretRect>`

Resolves with the caret's current pixel position relative to the input. For continuous tracking, prefer [`onCaretRectChange`](#oncaretrectchange).

<LivePreview src={CaretSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `toggleBold()`

Toggles bold on the current selection or cursor.

<LivePreview src={ToggleBoldSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `toggleItalic()`

Toggles italic on the current selection or cursor.

<LivePreview src={ToggleItalicSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `toggleUnderline()`

Toggles underline on the current selection or cursor.

<LivePreview src={ToggleUnderlineSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `toggleStrikethrough()`

Toggles strikethrough on the current selection or cursor.

<LivePreview src={ToggleStrikethroughSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `toggleSpoiler()`

Toggles spoiler on the current selection or cursor.

<LivePreview src={ToggleSpoilerSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `toggleHeading(level: number)`

Toggles a heading of the given level (`1`-`6`) on the cursor's paragraph. Calling it with the level already applied turns the paragraph back into regular text.

:::note
Headings are single-line blocks. An emptied heading line stays a heading until you toggle it off, and pressing Enter at the end of a heading starts a regular paragraph (headings do not continue like list items).
:::

<LivePreview src={ToggleHeadingSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `toggleUnorderedList()`

Turns the cursor's paragraph(s) into bullet items, or back into regular paragraphs. Toggling one list type onto a line carrying the other replaces it, keeping the nesting depth.

<LivePreview src={ToggleUnorderedListSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `toggleOrderedList()`

Same as above for numbered items. Numbering derives from each item's position among its adjacent same-depth siblings, so it stays correct as items are added, removed, or reordered.

<LivePreview src={ToggleOrderedListSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `indentList()`

Nests the current item one level deeper (up to a maximum). On a non-list paragraph it starts a bullet list. Equivalent to **Tab** on a hardware keyboard.

<LivePreview src={IndentOutdentSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `outdentList()`

Lifts the current item out one level. Outdenting a depth-0 item removes the bullet. Equivalent to **Shift+Tab**. The [`indentList()` example](#indentlist) above includes an outdent button.

:::note
Pressing **Return** inside an item starts a new item at the same depth; pressing it on an empty item exits the list. **Backspace** at the start of an item outdents it. List items are single-line: Markdown imported with multi-paragraph (loose) items keeps only each item's first line as a list item.
:::

### `setLink(url: string)`

Applies a link URL to the currently selected text.

<LivePreview src={SetLinkSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `insertLink(text: string, url: string)`

Inserts a new link with the given text and URL at the cursor. Useful when there is no selection.

<LivePreview src={InsertLinkSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `removeLink()`

Removes the link from the current selection.

<LivePreview src={RemoveLinkSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `startMention(indicator: string)`

Programmatically starts a mention flow by inserting `indicator` at the cursor. The indicator must be listed in [`mentionIndicators`](#mentionindicators). Useful for toolbar buttons.

<LivePreview src={StartMentionSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

### `insertMention(displayText: string, url: string)`

Replaces the active mention token with a formatted link, serialized as `[displayText](url)`. Only works while a mention flow is active.

<LivePreview src={MentionsSrc} unavailable unavailableLabel="Coming soon" unavailableReason={soon} />

## See also

- [Mentions](/rich-text-formatting/mentions) - trigger indicators, suggestion events, and per-pattern link styling.
- [EnrichedMarkdownText](/react-native/api-reference/enriched-markdown-text) - the read-only renderer that pairs with this input.
- [Style properties](/react-native/api-reference/style-properties) - all styleable properties, including a dark-mode recipe.
- [Testing with Jest](/react-native/guides/testing) - the shipped Jest mock for asserting on input, ref methods, and emitted Markdown.
- [RTL support](/misc/rtl) - right-to-left languages and per-element RTL behavior.
