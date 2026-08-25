---
sidebar_label: EnrichedMarkdownTextInput
sidebar_position: 2
---

# EnrichedMarkdownTextInput

:::caution
THIS PAGE IS WORK IN PROGRESS
:::

`EnrichedMarkdownTextInput` is a rich text input component that outputs Markdown. It is an uncontrolled input — it doesn't use any state or props to store its value, but instead directly interacts with the underlying platform-specific components. Thanks to this, the component is really performant and simple to use.

## Usage

Here's a simple example of an input that lets you toggle bold on its text and shows whether bold is currently active via the button color.

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
      <View style={styles.toolbar}>
        <Button
          title={state?.bold.isActive ? 'Unbold' : 'Bold'}
          color={state?.bold.isActive ? 'green' : 'gray'}
          onPress={() => ref.current?.toggleBold()}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  input: { width: '100%', fontSize: 20, padding: 10, maxHeight: 200, backgroundColor: 'lightgray' },
  toolbar: { flexDirection: 'row', gap: 8, marginTop: 8 },
});
```

Summary of what happens here:

1. Any methods imperatively called on the input to e.g. toggle some style must be used through a `ref` of `EnrichedMarkdownTextInputInstance` type. Here, the `toggleBold` method that is called on the button press calls `ref.current?.toggleBold()`, which toggles the bold styling within the current selection.
2. All style state information is emitted by the `onChangeState` callback. The callback payload provides a nested object for each style (e.g. `bold`, `italic`), containing an `isActive` property to guide your UI logic — indicating if the style is currently applied so you can highlight the button.

## Inline styles

Supported styles:

- bold
- italic
- underline
- strikethrough
- spoiler

Each of the styles can be toggled the same way as in the [example above](#usage); call the proper `toggle` function on the component ref.

Each call toggles the style within the current text selection, on exactly the character range that is currently selected. When toggling the style with just the cursor in place (no selection), the style is ready to be used and will be applied to the next characters that the user inputs.

Styles are also available through the built-in native format bar that appears on text selection, and through the system context menu.

## Headings

Supported heading levels: H1–H6.

Headings are block-level: a heading applies to the whole paragraph the cursor (or selection) touches, unlike [inline styles](#inline-styles) which apply to a character range. Toggle a heading by calling `toggleHeading(level)` on the component ref with a level from `1` to `6`:

```tsx
<Button title="H1" onPress={() => ref.current?.toggleHeading(1)} />
```

Calling `toggleHeading` with the level already applied to the cursor's paragraph turns the heading back into a regular paragraph. The cursor's current heading level is reported through the `onChangeState` payload as `heading: { isActive, level }` (`level` is `0` when the paragraph is not a heading), so you can highlight the active level in your toolbar.

Behavior notes:

- An emptied heading line stays a heading until you toggle it off, so characters you type next continue at the heading size.
- Pressing Enter at the end of a heading starts a regular paragraph on the next line (headings do not continue like list items).

Heading font sizes, weights, and colors are configurable per level — see [Customizing styles](#customizing-styles).

## Links

Links are a piece of text with a URL attributed to it. They can be managed by calling methods on the input ref:

- `setLink(url)` — applies a link to the currently selected text.
- `insertLink(text, url)` — inserts a new link at the cursor position with the given text and URL. Useful when there is no selection.
- `removeLink()` — removes the link from the current selection.

The built-in native format bar also includes a link option that presents a URL prompt when text is selected.

## Auto-link detection

`EnrichedMarkdownTextInput` can automatically detect URLs as the user types and convert them into Markdown links. Detected links are visually styled in the input and serialized as `[text](url)` in the Markdown output.

### Basic usage

Auto-link detection is enabled by default. URLs like `google.com`, `www.google.com`, and `https://google.com` are detected when followed by a space or newline.

Bare domains and `www.` prefixes are automatically normalized with `https://` (e.g. `google.com` becomes `[google.com](https://google.com)`).

### Custom regex

You can provide a custom regex pattern to control which text is detected as a link:

```tsx
<EnrichedMarkdownTextInput
  linkRegex={/https?:\/\/[^\s]+/i}
/>
```

Pass `null` to disable auto-link detection entirely:

```tsx
<EnrichedMarkdownTextInput linkRegex={null} />
```

### Listening for detections

Use the `onLinkDetected` callback to be notified when a new link is detected:

```tsx
<EnrichedMarkdownTextInput
  onLinkDetected={({ text, url, start, end }) => {
    console.log(`Detected link: ${text} -> ${url} at [${start}, ${end}]`);
  }}
/>
```

The callback fires only for newly detected links — not for links that were already detected and remain unchanged.

### Interaction with manual links

When a manual link is applied (via `setLink` or `insertLink`) over an auto-detected link, the auto-detected link is replaced by the manual one. Auto-link detection skips ranges that already contain a manual link.

## Caret position tracking

`EnrichedMarkdownTextInput` can report the caret's pixel position relative to the input, which is useful when the input is embedded in a scrollable container with `scrollEnabled={false}` and you need to keep the caret visible.

### `onCaretRectChange`

A push-based callback that fires whenever the caret moves (typing, selection change, content reflow). The native side diffs the caret rect before emitting, so redundant events are suppressed automatically.

```tsx
<EnrichedMarkdownTextInput
  scrollEnabled={false}
  onCaretRectChange={(rect) => {
    console.log(rect);
  }}
/>
```

### `getCaretRect()`

An imperative, pull-based method for one-off queries. Returns a Promise that resolves with the current caret rect.

```tsx
const rect = await ref.current?.getCaretRect();
```

## Mentions

`EnrichedMarkdownTextInput` supports mention flows with configurable trigger indicators, lifecycle events for showing suggestion lists, and per-pattern styling via `linkVariants`.

See [Mentions](/rich-text-formatting/mentions) for full documentation on setup, events, ref methods, and styling.

## Clipboard

The input's content can be copied to the system clipboard from a ref, without requiring the user to select text and open the context menu:

- `copyToClipboard()` — copies the full content to the system clipboard, matching the result of selecting all text and pressing the context menu's copy action. The selection is left unchanged, and calling it on an empty input is a no-op.

On iOS and macOS the clipboard receives both plain text and a private Markdown pasteboard type, so pasting back into an `EnrichedMarkdownTextInput` restores the formatting; external apps receive plain text only. On Android the clipboard receives plain text only — inline styles are not preserved for any paste target.

## Style detection

All of the above styles can be detected with the use of the `onChangeState` callback payload. You can find some examples in the [usage section](#usage).

## Other events

`EnrichedMarkdownTextInput` emits a few more events that may be of use:

- `onFocus` — emits whenever the input focuses.
- `onBlur` — emits whenever the input blurs.
- `onChangeText` — returns the input's plain text (without Markdown syntax) anytime it changes.
- `onChangeMarkdown` — returns the Markdown string parsed from the current input text and styles anytime it would change. As parsing the Markdown on each input change can be expensive, not assigning the event's callback will skip the serialization for better performance.
- `onChangeSelection` — returns `{ start, end }` of the current selection, useful for working with [links](#links).

## RTL support

`EnrichedMarkdownTextInput` resolves writing direction **per paragraph**, matching the read-only [`EnrichedMarkdownText`](/react-native/api-reference/enriched-markdown-text) renderer. Arabic, Hebrew, and Persian content right-aligns automatically as the user types — even mixed with English paragraphs in the same input.

### Platform setup

No setup is required. Both platforms autodetect direction per paragraph out of the box.

- **Android** — `EditText` resolves direction per paragraph via `View.TEXT_DIRECTION_FIRST_STRONG` (the platform default). The `writingDirection` prop is accepted but has no effect.
- **iOS** — TextKit's `NSWritingDirectionNatural` follows the app's global UI layout direction and does not do per-paragraph first-strong. The library applies first-strong itself after every formatting pass. The mode is controlled by `writingDirection` and defaults to `'first-strong'`.

### `writingDirection` prop (iOS)

| Value | Behavior |
|---|---|
| `'first-strong'` (default) | Per-paragraph autodetection. Neutral-only paragraphs fall back to the view's resolved layout direction. Matches Android. |
| `'auto'` | React Native parity. TextKit follows the app's `userInterfaceLayoutDirection`; mixed-direction documents do not auto-resolve. |
| `'ltr'` | Forces LTR on every paragraph. |
| `'rtl'` | Forces RTL on every paragraph. |

```tsx
<EnrichedMarkdownTextInput writingDirection="rtl" placeholder="اكتب هنا..." />
```

### Known limitations

- **Placeholder** follows the host view's layout direction, not the prop. If you need an RTL placeholder, wrap the input in `<View style={{ direction: 'rtl' }}>` or set `I18nManager.forceRTL(true)`.
- **Mixed paragraphs while typing** — newly inserted characters in an empty paragraph briefly inherit the previous paragraph's direction; the first-strong pass corrects this on the next input event.
- **Code blocks, tables, blockquotes, lists** are not supported in the input (it's a flat inline-formatting surface). For those, use [`EnrichedMarkdownText`](/react-native/api-reference/enriched-markdown-text).

See [RTL support](/misc/rtl) for the full per-element behavior on the rendered output side.

## Customizing styles

`EnrichedMarkdownTextInput` accepts a `markdownStyle` prop for customizing how formatted text appears in the input:

```tsx
<EnrichedMarkdownTextInput
  markdownStyle={{
    strong: { color: '#1D4ED8' },
    em: { color: '#7C3AED' },
    link: { color: '#2563EB', underline: true },
    h1: { fontSize: 28, fontWeight: 'bold', color: '#111827' },
  }}
/>
```

Available style properties:

- `strong.color` — text color for bold text (defaults to the input's text color).
- `em.color` — text color for italic text (defaults to the input's text color).
- `link.color` — text color for links (defaults to `#2563EB`).
- `link.underline` — whether links are underlined (defaults to `true`).
- `spoiler.color` — text color for spoiler text.
- `spoiler.backgroundColor` — background color for spoiler text.
- `h1`–`h6` — per-level heading styling, each accepting `fontSize`, `fontWeight`, and `color`. Defaults match the read-only `EnrichedMarkdownText` renderer (sizes `30/24/20/18/16/14`, bold) so headings look the same in the editor and a rendered preview. Omitted levels (or fields) fall back to those defaults.
