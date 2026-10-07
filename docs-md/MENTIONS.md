# Mentions

`EnrichedMarkdownTextInput` supports mention flows — token-triggered inline entities (e.g. `@user`, `#channel`) rendered as styled links.

## How It Works

1. User types an indicator (`@`, `#`) or toolbar calls `startMention(indicator)`.
2. `onStartMention` fires → show suggestion list.
3. `onChangeMention` fires on each keystroke → filter suggestions by query.
4. User picks a suggestion → call `insertMention(displayText, url)`.
5. `onEndMention` fires → hide suggestions.

## Example

```tsx
<EnrichedMarkdownTextInput
  ref={ref}
  mentionIndicators={['@', '#']}
  markdownStyle={{
    link: { color: '#2563EB', underline: true },
    linkVariants: {
      '^user:': { color: '#1264A3', backgroundColor: '#E8F5FB', underline: false },
      '^channel:': { color: '#065F46', backgroundColor: '#D1FAE5', underline: false },
    },
  }}
  onStartMention={({ indicator }) => setShowSuggestions(true)}
  onChangeMention={({ indicator, text }) => setQuery(text)}
  onEndMention={() => setShowSuggestions(false)}
  onCaretRectChange={setCaretRect} // for positioning the popup
/>
```

When the user selects a suggestion:

```tsx
ref.current?.insertMention(`@${item.name}`, item.url);
// Markdown output: [@Alice](user://u_1)
```

## Props

| Prop | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `mentionIndicators` | `string[]` | `[]` | Trigger strings that start a mention flow. |

## Events

| Event | Payload | When |
| ----- | ------- | ---- |
| `onStartMention` | `{ indicator }` | Mention flow starts. |
| `onChangeMention` | `{ indicator, text }` | Query text changes (each keystroke). |
| `onEndMention` | `{ indicator }` | Mention flow ends (cancel, insert, or cursor moved away). |

## Ref Methods

| Method | Description |
| ------ | ----------- |
| `startMention(indicator)` | Inserts the indicator at cursor and triggers the mention flow. Must be in `mentionIndicators`. |
| `insertMention(displayText, url)` | Replaces the active mention token with a styled link. Only works during an active flow. |

## Link Variants (Styling)

Mentions are links — style them per URL pattern via `linkVariants` in `markdownStyle`:

```tsx
linkVariants: {
  '^user:':    { color: '#1264A3', backgroundColor: '#E8F5FB', underline: false },
  '^channel:': { color: '#065F46', backgroundColor: '#D1FAE5', underline: false },
}
```

`fontFamily` can be overridden per variant and otherwise inherits the base `link` family.

Each key is a regex tested against the link URL. First match wins. Unspecified properties inherit from the base `link` style. Patterns are auto-sorted longest-first.

## Native link pills

Readonly `EnrichedMarkdownText` can present links as pills on iOS and Android: a rounded box with an optional icon and label that wraps as one unit. It works everywhere links render, including GFM table cells. This does not change the text-input mention API.

Pills have two parts:

- **Presentation** lives in `markdownStyle.linkVariants`: which links are pills, their colors and geometry, and an optional label and icon shared by every link the pattern matches.
- **Per-link content** lives in the `linkPillContent` prop: a label and icon for one exact URL. It is content, not style, so `markdownStyle` can stay a stable constant while this map changes.

```tsx
const markdownStyle = {
  linkVariants: {
    '^https://example\\.com/files/': {
      color: '#3730A3',
      backgroundColor: '#EEF2FF',
      underline: false,
      pill: {
        iconUri: 'file_icon',
        borderRadius: 10,
        paddingHorizontal: 7,
        paddingVertical: 2,
        borderWidth: 1,
        borderColor: '#C7D2FE',
        maxWidth: 220,
      },
    },
    '^user:': { color: '#065F46', backgroundColor: '#ECFDF5', pill: true },
  },
};

<EnrichedMarkdownText
  markdown="Open [src/components/Button.tsx](https://example.com/files/src/components/Button.tsx) or ask [@gregory](user:gregory)."
  markdownStyle={markdownStyle}
  linkPillContent={{
    'https://example.com/files/src/components/Button.tsx': {
      label: 'Button.tsx',
    },
    'user:gregory': { iconUri: avatarUri },
  }}
/>;
```

### Presentation: `linkVariants[pattern].pill`

`pill` defaults to `false`. Set it to `true` for the default look or to an object to override it. The variant's `color`, `underline`, `backgroundColor` and `fontFamily` apply to the pill.

| Field                    | Default            | Meaning                                                               |
| ------------------------ | ------------------ | --------------------------------------------------------------------- |
| `pill.label`             | Original link text | Label shown by every link the pattern matches.                        |
| `pill.iconUri`           | No icon            | Icon shown by every link the pattern matches. See icon sources below. |
| `pill.borderRadius`      | `8`                | Corner radius in points/DIP.                                          |
| `pill.paddingHorizontal` | `6`                | Horizontal inset in points/DIP.                                       |
| `pill.paddingVertical`   | `2`                | Vertical inset in points/DIP.                                         |
| `pill.lineHeight`        | Not set            | Minimum line height of a block that holds the pill. See below.        |
| `pill.borderWidth`       | `0`                | Border width in points/DIP.                                           |
| `pill.borderColor`       | Transparent        | Border color.                                                         |
| `pill.maxWidth`          | `0`                | Positive maximum width in points/DIP. Zero uses available text width. |

Nonfinite dimensions use defaults and negative dimensions clamp to zero.

A pill is as tall as its font's line plus `paddingVertical` and `borderWidth` on both sides. A line grows to fit a pill, but only to the pill's own height, so pills on consecutive lines touch when the line height leaves no room. `pill.lineHeight` is for that case: a paragraph, list item, heading or quote that holds the pill gets lines at least that tall, on every line, so its spacing stays even. It only ever raises the block's own `lineHeight`, it does not size the pill, and blocks without pills are unaffected.

For text that streams in, set the block's own `lineHeight` to that value instead. With `pill.lineHeight` a paragraph's line height depends on whether it holds a pill, so while streaming it changes the moment a link completes and becomes one, and the text around it moves. A block `lineHeight` is the same before and after, so nothing moves.

### Per-link content: `linkPillContent`

`linkPillContent` maps an exact link URL to `{ label?, iconUri? }`. It only affects links whose variant enables `pill`. For both label and icon the order is: `linkPillContent` entry, then the variant's `pill.label` / `pill.iconUri`, then the link's own text (and no icon).

Lookup is by exact URL, so it stays cheap with hundreds of links, and changing it re-renders without touching `markdownStyle`. Keep the object reference stable between renders when its content has not changed.

### Behavior

- The label uses the font of the surrounding text, including bold and italic applied around the link. Long labels truncate at the tail; the pill never grows past the available text width.
- The label is presentation only. Plain copy, Copy as Markdown, HTML and RTF export, and the iOS system actions (Look Up, Translate, Share) receive the original link text. Tap and long-press callbacks receive the original URL.
- The accessible name is the visible label, followed by the original link text when they differ.
- Links whose text contains an image, inline math, a hard line break or a spoiler stay ordinary links.
- A pill inside an unrevealed spoiler is hidden with the rest of the spoiler.

### Icon sources

Icons are drawn at the label's font size.

| Source                                                                                | iOS | Android |
| ------------------------------------------------------------------------------------- | --- | ------- |
| File path, `file://` URI, bundled asset name                                          | Yes | Yes     |
| `http://`, `https://` (including `Image.resolveAssetSource(require(...)).uri` in dev) | Yes | Yes     |
| `data:` (base64)                                                                      | Yes | Yes     |
| Drawable/raw resource name, `asset://`, `res://`, `content://`                        | No  | Yes     |

Local files show on the first layout. Remote icons load in the background through the same pipeline as Markdown images, using `imageRequestHeaders`, and the pill keeps room for them while they load. A source that fails to load gives that room back, so the pill shrinks to its label, and is retried after 30 seconds.

Pill presentation is native only. Web and macOS render ordinary links and ignore `pill` and `linkPillContent`.

## Positioning the Suggestion List

Use `onCaretRectChange` to get the caret's `{ x, y, width, height }` relative to the input. Combine with the input's position (via `onLayout`) to place a floating popup:

```tsx
<View
  style={{
    position: 'absolute',
    left: inputLayout.x + caretRect.x,
    top: inputLayout.y + caretRect.y + caretRect.height + 4,
  }}
>
  {/* suggestions */}
</View>
```

For simpler layouts, just render the list adjacent to the input without caret tracking.

## Behavior Notes

- **Atomic deletion**: Backspacing into a mention deletes it entirely (Slack-like).
- **Debounce**: `onChangeMention` fires every keystroke — debounce network requests.
- **Toolbar**: Call `focus()` before `startMention()` if the input isn't focused.
- **URL schemes**: Use custom schemes (`user://`, `channel://`) to distinguish mention types from regular links.
