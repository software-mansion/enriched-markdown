# Markdown Streaming

`EnrichedMarkdownText` renders markdown while it streams, token by token from an LLM for example: new text fades in, incomplete blocks are held back and half-written inline syntax is repaired, all in native code.

## Migrating from react-native-streamdown or streamingAnimation

`react-native-streamdown` is deprecated: replace `StreamdownText` with `EnrichedMarkdownText` and set `streaming` while the text arrives. No Worklets setup is needed.

`streamingAnimation` is deprecated in favor of `streaming` and logs a warning in development. It no longer only animates: while it is on, incomplete blocks are held back and inline syntax is repaired, so turn it off when the stream ends, or the final render keeps doing so.

## Incremental Rendering

Feed the growing markdown string to `EnrichedMarkdownText` and set `streaming` while it arrives (off by default). Only the new characters fade in on each update. Set it back to `false` when the stream ends, so the final render shows everything; `onStreamingEnd` is called once the view has stopped streaming.

```tsx
<EnrichedMarkdownText
  markdown={partialMarkdown}
  streaming={isStreaming}
  onStreamingEnd={() => console.log('done')}
/>
```

Streaming assumes append-only updates: everything past the previous string's length is treated as new. `streamingAnimation` is a deprecated alias of `streaming`.

## Streaming Without Re-rendering

Passing a growing `markdown` re-renders your component on every chunk. A stream from `createMarkdownStream()` doesn't: append chunks to it and the view updates once per frame on its own, with the text kept in native memory.

```tsx
const stream = createMarkdownStream();
socket.onmessage = (event) => stream.append(event.data);
socket.onclose = () => stream.end();

<EnrichedMarkdownText stream={stream} flavor="github" />;
```

Keep the stream outside the component, so a list row that unmounts and mounts again shows the same text, and call `dispose()` when the message is gone.

## Incomplete Blocks

Some blocks can't be rendered until enough of them has arrived. The `streamingConfig` prop decides what happens in the meantime, in both flavors, while `streaming` is `true`.

```tsx
<EnrichedMarkdownText
  markdown={partialMarkdown}
  flavor="github"
  streaming={isStreaming}
  streamingConfig={{ tableMode: 'hidden', codeBlockMode: 'progressive' }}
/>
```

### Tables (`tableMode`, GFM only)

| Mode | Behavior |
|---|---|
| `'progressive'` (default) | Renders the table row-by-row as content arrives. New rows fade in unless `animation` is `'none'`. Incomplete trailing rows are automatically trimmed. |
| `'hidden'` | The table is completely hidden until it is followed by a blank line, indicating the table is complete. Prevents visual jank from partially formed tables. |

### Code Blocks (`codeBlockMode`)

While a block's closing fence (```` ``` ````) has not arrived, its content is still changing, which would otherwise make syntax highlighting flicker on every token.

| Mode | Behavior |
|---|---|
| `'progressive'` (default) | The code streams in line-by-line with its header (language label + copy button) visible but non-interactive — copying is disabled until the block completes. Syntax highlighting is deferred so it applies once when the closing fence arrives instead of flickering per token. |
| `'hidden'` | The entire code block is hidden until its closing fence arrives, then it appears complete (the same all-or-nothing behavior block math uses). |

### Images, Videos and Links (`mediaMode`)

| Mode | Behavior |
|---|---|
| `'progressive'` (default) | Shows a trailing image paragraph, link paragraph or `<video>` block once its syntax is complete; a half-streamed `![alt](https://…` or `[label](https://…` is withheld instead of flashing as text. |
| `'hidden'` | Withholds the block until a blank line or another block follows it. |

An unterminated `$$` block math is always withheld until its closing `$$` arrives.

## Arrival Animation (`animation`)

| Value | Behavior |
|---|---|
| `'fade'` (default) | Each new word fades in over its own 200 ms; new blocks and table rows fade in. |
| `'gradient'` | The last 20 characters run from their own color to transparent, following the end of the text as it grows, and settle to their own colors over 200 ms when the stream ends. |
| `'none'` | Nothing animates; the incomplete-block handling above still applies. |

A preset with its options: `{ type: 'fade', duration }` sets the text's fade in milliseconds (blocks and table rows keep 200 ms); `{ type: 'gradient', length, startColor, endColor }` sets how many characters it covers and the colors at its start and end.

```tsx
<EnrichedMarkdownText
  markdown={partialMarkdown}
  streaming={isStreaming}
  streamingConfig={{ animation: { type: 'gradient', length: 15, startColor: '#107ACA', endColor: 'transparent' } }}
/>
```

Animations change only how characters are drawn, never the text. Reduce Motion turns them off.

## Smooth Pacing (`smooth`)

`streamingConfig.smooth` reveals the text word by word at a steady pace instead of in the bursts it arrives in, so lines, list items and blocks grow with the words. Each chunk spreads over the time until the next one, at most a second behind; when the stream ends, what is left shows within 200 ms, and `onStreamingEnd` fires then. Off by default. It works with every animation, and Reduce Motion keeps the pacing and turns off only the animation.

```tsx
<EnrichedMarkdownText markdown={partialMarkdown} streaming={isStreaming} streamingConfig={{ smooth: true }} />
```

## Half-Written Inline Syntax

Inline markdown still being typed at the end is repaired, so it never flashes as raw syntax: emphasis, strikethrough and inline code get their closers, a link shows its label until its URL is complete, and an image, unclosed inline math or a lone marker line waits until it can render. Finished blocks are never touched again.
