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

Readonly `EnrichedMarkdownText` supports optional pill presentation on iOS and Android through the same `markdownStyle.linkVariants` map. It also works for links in GFM table cells. This does not change the text-input mention API.

```tsx
<EnrichedMarkdownText
  markdown="See [original label](https://example.com/document)."
  markdownStyle={{
    linkVariants: {
      '^https://example\\.com/document$': {
        pill: {
          label: 'Document',
          iconUri: 'file:///path/to/bundled-icon.png',
          borderRadius: 8,
          paddingHorizontal: 6,
          paddingVertical: 2,
          borderWidth: 1,
          borderColor: '#B8DDF0',
          maxWidth: 180,
        },
        fontFamily: 'CustomFont',
        color: '#1264A3',
        underline: false,
        backgroundColor: '#E8F5FB',
      },
    },
  }}
/>
```

`pill` defaults to `false`. Set it to `true` for default presentation or an object for overrides. `null` also disables pills. The presentation `pill.label` never replaces the original link text used for plain copy, Markdown extraction, or selection. The accessible name includes the visible label followed by the original link text when they differ. Missing or empty labels use the original text. Tap and long-press callbacks still receive the original URL, and existing link menus continue to work.

| Field                    | Default            | Meaning                                                               |
| ------------------------ | ------------------ | --------------------------------------------------------------------- |
| `fontFamily`             | Base link family   | Link font family, including ordinary links.                           |
| `pill`                   | `false`            | Opt into atomic native presentation.                                  |
| `pill.label`             | Original link text | Presentation label.                                                   |
| `pill.iconUri`           | No icon            | Local or bundled image URI. Unreadable sources are ignored.           |
| `pill.borderRadius`      | `8`                | Corner radius in points/DIP.                                          |
| `pill.paddingHorizontal` | `6`                | Horizontal inset in points/DIP.                                       |
| `pill.paddingVertical`   | `2`                | Vertical inset in points/DIP.                                         |
| `pill.borderWidth`       | `0`                | Border width in points/DIP.                                           |
| `pill.borderColor`       | Transparent        | Border color.                                                         |
| `pill.maxWidth`          | `0`                | Positive maximum width in points/DIP. Zero uses available text width. |

The existing `color`, `underline`, and `backgroundColor` fields still apply. Pill labels truncate at the tail and wrap as one unit. The width limit also accounts for native container width and block indentation. Nonfinite dimensions use defaults and negative dimensions clamp to zero.

Pill presentation is currently native only. Web renders ordinary links and retains their original labels. Links containing image or math attachments retain their existing native rendering. Icons use the existing local image resolver. iOS supports file paths, `file://` URIs, and file-backed bundle names including `@2x`/`@3x` variants. Asset-catalog-only images have no thumbnail-readable path and render no icon. Android also supports bundled drawable/raw resources, assets, content and data URIs. Remote URLs and unreadable sources render no icon.

`pill.iconTintColor` optionally applies a source-in tint to native pill icons, preserving image alpha. Omit it to keep the image's original colors. An explicit `transparent` tint hides the pixels while retaining icon space. Tint is applied per presentation and leaves cached originals unchanged.

Icon decoding is downsampled to approximately 512 pixels. Android caches are bounded to 64 images and 8 MiB. iOS uses a pressure-aware `NSCache` configured with the same count and decoded-byte cost limits; images held by visible pills are separate from this cache budget. File metadata changes invalidate cached icons.

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
