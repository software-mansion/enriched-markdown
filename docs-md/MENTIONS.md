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

Each key is a regex tested against the link URL. First match wins. Unspecified properties inherit from the base `link` style. Patterns are auto-sorted longest-first.

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
