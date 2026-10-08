---
sidebar_label: Mentions
sidebar_position: 1
---

import DisplayMentionsSrc from '!!raw-loader!@site/src/examples/react-native/rich-text-formatting/mentions/DisplayMentions';

# Mentions

A mention is just a Markdown link with a custom URL scheme - `[@Alice](user://alice)`. There is no dedicated mention token, which means mentions work with **both** components: `EnrichedMarkdownText` displays them as styled, tappable links, and `EnrichedMarkdownTextInput` additionally lets users author them interactively as they type.

## A mention is just a link {#styling-mentions-with-linkvariants}

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

Each key is a regex tested against the link URL; the first match wins, unspecified properties fall back to the base `link` style, and patterns are auto-sorted longest-first.

Both components accept a `linkVariants` key, so the same config styles mentions in the renderer and the editor. The two types are not quite interchangeable, though: the renderer's `LinkVariantStyle` has a `fontFamily` field and the editor's does not, so an object you intend to share must leave `fontFamily` unset to typecheck as `MarkdownTextInputStyle`.

- **Interaction** is through the usual link callbacks - a mention tap is a link tap, delivered with the mention's URL.

## Displaying mentions

Rendering content that already contains mentions needs nothing special: pass the Markdown to the display component, style the schemes with `linkVariants`, and route taps by scheme in `onLinkPress`.

<LivePreview src={DisplayMentionsSrc} />

{/* UNRELEASED PLATFORMS: the standalone iOS and Android SDKs display mentions
(a mention tap is an ordinary link tap, routed by scheme through the SwiftUI
`openURL` action / Compose `onLinkClick`), but neither has a `linkVariants`
equivalent, so a mention cannot be styled apart from a regular link there.
Restore those tabs, and the links to /ios/api-reference/style-properties#link
and /android/api-reference/enriched-markdown-text#onlinkclick, when those
packages ship. */}

That is the whole story for read-only surfaces - message lists, comment threads, previews. It works on web too. The rest of this page is about letting users _write_ mentions in the editor, which is **native only** - there is no web editor, so none of the authoring API below exists on web.

## Authoring mentions

`EnrichedMarkdownTextInput` turns typed indicators into mention links through an interactive flow that you pair with your own suggestion UI. The library does not ship a picker - render it however you like (a popover, a bottom sheet, an inline row).

### The mention flow

1. The user types an indicator you listed in `mentionIndicators` - or a toolbar calls `startMention('@')`. `onStartMention` fires; show your list. There is no default: with the prop unset no flow ever starts, and `['@', '#']` is a typical choice.
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
  type MarkdownTextInputStyle,
} from 'react-native-enriched-markdown';

const USERS = [
  { name: 'Alice', url: 'user://alice' },
  { name: 'Bob', url: 'user://bob' },
  { name: 'Carol', url: 'user://carol' },
];

// The composer re-renders on every keystroke, so keep the style object out of
// JSX. It depends on nothing here, so module scope is enough; build it with
// useMemo when it derives from state or props.
const MENTION_STYLE: MarkdownTextInputStyle = {
  linkVariants: {
    '^user:': { color: '#1264A3', underline: false },
  },
};

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
        markdownStyle={MENTION_STYLE}
        // Reset the query on every new flow: native does not emit a
        // Change event for the bare indicator, so a stale query would
        // pre-filter the list the second time around.
        onStartMention={() => {
          setQuery('');
          setOpen(true);
        }}
        onChangeMention={({ text }) => setQuery(text)}
        onEndMention={() => {
          setQuery('');
          setOpen(false);
        }}
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
</CodeTabs>

{/* UNRELEASED PLATFORMS: neither standalone SDK has an editor, so there is no
mention-authoring equivalent on iOS or Android today. */}

### Building the matching engine

The library's job ends at detection. It watches the caret, isolates the active token, strips the indicator, and hands you the query through `onChangeMention` - that is all the native side does. Everything downstream is ordinary React state that you own:

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

// Remote - fetch ranked results from your backend, straight from the handler:
//   onChangeMention={({ text }) => debouncedSearch(text).then(setMatches)}
```

The same handler is free to score, sort, highlight, or group results before rendering - the library never sees your list.

:::tip
Custom matching is a JavaScript concern, not a native one. Swapping `startsWith` for fuzzy or remote search needs no config on `EnrichedMarkdownTextInput` - only debounce anything network-backed, since `onChangeMention` fires on every keystroke.
:::

### Positioning the suggestion list

`onCaretRectChange` reports the caret's `{ x, y, width, height }` relative to the input. Combine it with the input's own position (`onLayout` gives you a position relative to the parent; use `measureInWindow` on the ref for screen coordinates) to anchor a floating popup just below the caret:

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
- **`insertMention` needs an active flow** - outside one it is a no-op, so a "recent mentions" toolbar button must use `insertLink(text, url)` instead.
- **A trailing space is appended** by `insertMention` unless the next character is already whitespace, and the caret is parked after it.
- **A flow never starts inside an existing link**, which is what makes re-editing an inserted mention inert.
- **No `Change` event for a bare indicator** - typing `@` alone emits `onStartMention` and no `onChangeMention`, which is why the example resets `query` on start.

:::caution
Indicator matching is **first-in-array, not longest-match**: the first entry of `mentionIndicators` that prefixes the token wins. With `['@', '@@']` the two-character indicator can never match, because `@` always matches first. List longer indicators first.
:::

## Reference

Displaying mentions uses ordinary display-component styling (`linkVariants` and the link-press callback); authoring adds the mention surface on the editor: a `mentionIndicators` prop, the start/change/end mention events, the `startMention` / `insertMention` ref methods, and a caret-rect change event for positioning.

- Prop [`mentionIndicators`](/react-native/api-reference/enriched-markdown-text-input#mentionindicators) - the trigger strings that start a flow.
- Events [`onStartMention`](/react-native/api-reference/enriched-markdown-text-input#onstartmention) `{ indicator }`, [`onChangeMention`](/react-native/api-reference/enriched-markdown-text-input#onchangemention) `{ indicator, text }`, [`onEndMention`](/react-native/api-reference/enriched-markdown-text-input#onendmention) `{ indicator }`.
- Ref methods [`startMention(indicator)`](/react-native/api-reference/enriched-markdown-text-input#startmentionindicator-string) and [`insertMention(displayText, url)`](/react-native/api-reference/enriched-markdown-text-input#insertmentiondisplaytext-string-url-string).
- [`onCaretRectChange`](/react-native/api-reference/enriched-markdown-text-input#oncaretrectchange) - caret geometry for positioning.
- Displaying: [`EnrichedMarkdownText`](/react-native/api-reference/enriched-markdown-text) with `markdownStyle.linkVariants` and `onLinkPress`.

{/* UNRELEASED PLATFORMS: half of this reference exists natively - the
standalone SDKs can display and route mentions - but neither has an editor or a
`linkVariants` equivalent. Restore the iOS/Android tabs when they ship. */}
