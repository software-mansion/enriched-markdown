---
sidebar_label: Mentions
sidebar_position: 1
---

# Mentions

A mention is just a Markdown link with a custom URL scheme - `[@Alice](user://alice)`. There is no dedicated mention token, which means mentions work with **both** components: `EnrichedMarkdownText` displays them as styled, tappable links, and `EnrichedMarkdownTextInput` additionally lets users author them interactively as they type.

## A mention is just a link

Because a mention is an ordinary link, everything the library already does with links applies:

- **Styling** is per URL scheme, through `linkVariants` in `markdownStyle` - a map of URL-pattern to style. Give each mention type its own scheme (`user://`, `channel://`) so you can style them apart from each other and from regular links:

```tsx
markdownStyle={{
  link: { color: '#2563EB', underline: true }, // ordinary links
  linkVariants: {
    '^user:':    { color: '#1264A3', backgroundColor: '#E8F5FB', underline: false },
    '^channel:': { color: '#065F46', backgroundColor: '#D1FAE5', underline: false },
  },
}}
```

Each key is a regex tested against the link URL; the first match wins, unspecified properties fall back to the base `link` style, and patterns are auto-sorted longest-first. `linkVariants` is a shared style property, so the same config styles mentions in the renderer and the editor alike.

- **Interaction** is through the usual link callbacks - a mention tap is a link tap, delivered with the mention's URL.

## Displaying mentions

Rendering content that already contains mentions needs nothing special: pass the Markdown to the display component, style the schemes with `linkVariants`, and route taps by scheme in `onLinkPress`.

<CodeTabs groupId="platform">
<Tab label="React Native">

```tsx
<EnrichedMarkdownText
  markdown={'Hey [@Alice](user://alice), check [#general](channel://general).'}
  markdownStyle={{
    linkVariants: {
      '^user:': { color: '#1264A3', underline: false },
      '^channel:': { color: '#065F46', underline: false },
    },
  }}
  onLinkPress={({ url }) => {
    if (url.startsWith('user://')) openProfile(url);
    else if (url.startsWith('channel://')) openChannel(url);
  }}
/>
```

</Tab>
<Tab label="iOS"><ComingSoon platform="iOS" /></Tab>
<Tab label="Android"><ComingSoon platform="Android" /></Tab>
</CodeTabs>

That is the whole story for read-only surfaces - message lists, comment threads, previews. The rest of this page is about letting users _write_ mentions in the editor.

## Authoring mentions

`EnrichedMarkdownTextInput` turns typed indicators into mention links through an interactive flow that you pair with your own suggestion UI. The library does not ship a picker - render it however you like (a popover, a bottom sheet, an inline row).

### The mention flow

1. The user types an indicator from `mentionIndicators` (`@`, `#`) - or a toolbar calls `startMention('@')`. `onStartMention` fires; show your list.
2. As they keep typing, `onChangeMention` fires on each keystroke with the current query `text`; filter your list.
3. The user picks a result and you call `insertMention(displayText, url)`. The active token becomes a link.
4. `onEndMention` fires when the flow ends - a pick, a cancel, or the caret moving away; hide your list.

### A complete example

A minimal composer wiring the whole flow together: it opens a list on `@`, filters it by the query, and inserts the chosen user as a mention. The `linkVariants` here style the inserted mention exactly as the renderer would.

<CodeTabs groupId="platform">
<Tab label="React Native">

```tsx
import { useRef, useState } from 'react';
import { View, Text, Pressable } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
  type CaretRect,
} from 'react-native-enriched-markdown';

const USERS = [
  { name: 'Alice', url: 'user://alice' },
  { name: 'Bob', url: 'user://bob' },
  { name: 'Carol', url: 'user://carol' },
];

export default function Composer() {
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [caret, setCaret] = useState<CaretRect>({
    x: 0,
    y: 0,
    width: 0,
    height: 0,
  });

  const matches = USERS.filter(u =>
    u.name.toLowerCase().startsWith(query.toLowerCase()),
  );

  return (
    <View>
      <EnrichedMarkdownTextInput
        ref={ref}
        mentionIndicators={['@']}
        markdownStyle={{
          linkVariants: {
            '^user:': { color: '#1264A3', underline: false },
          },
        }}
        onStartMention={() => setOpen(true)}
        onChangeMention={({ text }) => setQuery(text)}
        onEndMention={() => setOpen(false)}
        onCaretRectChange={setCaret}
      />

      {open && matches.length > 0 && (
        <View
          style={{
            position: 'absolute',
            top: caret.y + caret.height + 4,
            left: caret.x,
          }}>
          {matches.map(user => (
            <Pressable
              key={user.url}
              onPress={() => {
                // Replaces the active "@que" token with [@Alice](user://alice)
                ref.current?.insertMention(`@${user.name}`, user.url);
                setOpen(false);
              }}>
              <Text>@{user.name}</Text>
            </Pressable>
          ))}
        </View>
      )}
    </View>
  );
}
```

</Tab>
<Tab label="iOS"><ComingSoon platform="iOS" /></Tab>
<Tab label="Android"><ComingSoon platform="Android" /></Tab>
</CodeTabs>

### Building the matching engine

The library's job ends at detection. It watches the caret, isolates the active token, strips the indicator, and hands you the query through `onChangeMention` - that is the whole of the native contribution. Everything downstream is ordinary React state that you own:

1. **Receive** the query from `onChangeMention({ text })` - a plain string, one whitespace-delimited token with the indicator already removed.
2. **Match and rank** it against your data however you like.
3. **Render** the results in your own suggestion UI.
4. **Insert** the chosen result with `insertMention(displayText, url)`.

Because the query arrives as plain text, the matching strategy is entirely yours - there is no `filterMentions` prop or built-in matcher to configure. The example above uses a case-insensitive `startsWith`, but nothing in the library assumes prefix matching:

```tsx
// Prefix (as in the example above)
const matches = USERS.filter((u) => u.name.toLowerCase().startsWith(query.toLowerCase()));

// Substring - match anywhere in the name
const matches = USERS.filter((u) => u.name.toLowerCase().includes(query.toLowerCase()));

// Fuzzy - typo-tolerant ranking via a search library of your choice
const matches = query ? fuzzySearch(USERS, query) : USERS;

// Remote - fetch ranked results from your backend
onChangeMention={({ text }) => debouncedSearch(text).then(setMatches)}
```

The same handler is free to score, sort, highlight, or group results before rendering - the library never sees your list.

:::tip
Custom matching is a JavaScript concern, not a native one. Swapping `startsWith` for fuzzy or remote search needs no config on `EnrichedMarkdownTextInput` - only debounce anything network-backed, since `onChangeMention` fires on every keystroke.
:::

### Positioning the suggestion list

`onCaretRectChange` reports the caret's `{ x, y, width, height }` relative to the input. Combine it with the input's own on-screen position (from `onLayout`) to anchor a floating popup just below the caret:

```tsx
top: inputLayout.y + caret.y + caret.height + 4,
left: inputLayout.x + caret.x,
```

If the list sits inside the same container as the input (as in the example above), the input's offset is already accounted for and you can position from the caret alone. For simpler layouts, render the list next to the input without caret tracking at all.

### Behavior notes

- **Atomic deletion** - backspacing into a mention deletes the whole token, not one character (Slack-like).
- **Debounce** - `onChangeMention` fires on every keystroke, so debounce network-backed suggestion lookups.
- **Toolbar triggers** - call `focus()` before `startMention()` if the input isn't already focused.
- **URL schemes** - custom schemes (`user://`, `channel://`) both drive `linkVariants` styling and let your `onLinkPress` handler tell a mention from a normal link.

## Reference

Displaying mentions uses ordinary display-component styling (`linkVariants` and the link-press callback); authoring adds the mention surface on the editor: a `mentionIndicators` prop, the start/change/end mention events (`{ indicator }`, `{ indicator, text }`, `{ indicator }`), the `startMention` / `insertMention` ref methods, and a caret-rect change event for positioning. See your platform's reference for exact signatures and defaults.

<CodeTabs groupId="platform">
<Tab label="React Native">

- Prop [`mentionIndicators`](/react-native/api-reference/enriched-markdown-text-input#mentionindicators) - the trigger strings that start a flow.
- Events [`onStartMention`](/react-native/api-reference/enriched-markdown-text-input#onstartmention) `{ indicator }`, [`onChangeMention`](/react-native/api-reference/enriched-markdown-text-input#onchangemention) `{ indicator, text }`, [`onEndMention`](/react-native/api-reference/enriched-markdown-text-input#onendmention) `{ indicator }`.
- Ref methods `startMention(indicator)` and `insertMention(displayText, url)`.
- [`onCaretRectChange`](/react-native/api-reference/enriched-markdown-text-input#oncaretrectchange) - caret geometry for positioning.
- Displaying: [`EnrichedMarkdownText`](/react-native/api-reference/enriched-markdown-text) with `markdownStyle.linkVariants` and `onLinkPress`.

</Tab>
<Tab label="iOS"><ComingSoon platform="iOS" /></Tab>
<Tab label="Android"><ComingSoon platform="Android" /></Tab>
</CodeTabs>
