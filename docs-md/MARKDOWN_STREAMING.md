# Markdown Streaming

If you need to render markdown that streams token-by-token from an LLM, check out [react-native-streamdown](https://github.com/software-mansion-labs/react-native-streamdown) — a streaming-ready markdown component built on top of `react-native-enriched-markdown`.

It combines [remend](https://www.npmjs.com/package/remend) for fixing incomplete markdown on the fly with [react-native-worklets](https://docs.swmansion.com/react-native-worklets/) **Bundle Mode** to run all processing off the JS thread, keeping your UI responsive while tokens arrive.

```tsx
import { StreamdownText } from 'react-native-streamdown';

<StreamdownText markdown={partialMarkdown} />;
```

`StreamdownText` accepts all props from `EnrichedMarkdownText` and adds a `remendConfig` prop for customizing the markdown repair pipeline. See the [react-native-streamdown README](https://github.com/software-mansion-labs/react-native-streamdown#readme) for full setup instructions including the required Babel and Metro configuration for Bundle Mode.

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
| `'fade'` (default) | New text, blocks and table rows fade in. |
| `'none'` | Nothing animates; the incomplete-block handling above still applies. |

Reduce Motion turns the animation off.

## Half-Written Inline Syntax

Inline markdown still being typed at the end is repaired, so it never flashes as raw syntax: emphasis, strikethrough and inline code get their closers, a link shows its label until its URL is complete, and an image, unclosed inline math or a lone marker line waits until it can render. Finished blocks are never touched again.
