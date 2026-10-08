# Markdown Streaming

If you need to render markdown that streams token-by-token from an LLM, check out [react-native-streamdown](https://github.com/software-mansion-labs/react-native-streamdown) — a streaming-ready markdown component built on top of `react-native-enriched-markdown`.

It combines [remend](https://www.npmjs.com/package/remend) for fixing incomplete markdown on the fly with [react-native-worklets](https://docs.swmansion.com/react-native-worklets/) **Bundle Mode** to run all processing off the JS thread, keeping your UI responsive while tokens arrive.

```tsx
import { StreamdownText } from 'react-native-streamdown';

<StreamdownText markdown={partialMarkdown} />;
```

`StreamdownText` accepts all props from `EnrichedMarkdownText` and adds a `remendConfig` prop for customizing the markdown repair pipeline. See the [react-native-streamdown README](https://github.com/software-mansion-labs/react-native-streamdown#readme) for full setup instructions including the required Babel and Metro configuration for Bundle Mode.

## Table Streaming (GFM)

When using `flavor="github"` with streaming content, tables require special handling because they are block-level elements that can't be rendered until the parser has enough structure (at minimum a header row and separator line).

The `streamingConfig` prop controls this behavior:

```tsx
<EnrichedMarkdownText
  markdown={streamingMarkdown}
  flavor="github"
  streamingAnimation
  streamingConfig={{ tableMode: 'hidden' }}
/>
```

### Table Modes

| Mode | Behavior |
|---|---|
| `'progressive'` (default) | Renders the table row-by-row as content arrives. New rows fade in when `streamingAnimation` is enabled. Incomplete trailing rows are automatically trimmed. |
| `'hidden'` | The table is completely hidden until it is followed by a blank line, indicating the table is complete. Prevents visual jank from partially formed tables. |

## Code Block Streaming (GFM)

Fenced code blocks are also block-level elements. While a block's closing fence
(```` ``` ````) has not arrived, its content is still changing, which would
otherwise make syntax highlighting flicker on every token.

The `codeBlockMode` field of `streamingConfig` controls this:

```tsx
<EnrichedMarkdownText
  markdown={streamingMarkdown}
  flavor="github"
  streamingAnimation
  streamingConfig={{ codeBlockMode: 'progressive' }}
/>
```

### Code Block Modes

| Mode | Behavior |
|---|---|
| `'progressive'` (default) | The code streams in line-by-line with its header (language label + copy button) visible but non-interactive — copying is disabled until the block completes. Syntax highlighting is deferred so it applies once when the closing fence arrives instead of flickering per token. |
| `'hidden'` | The entire code block is hidden until its closing fence arrives, then it appears complete (the same all-or-nothing behavior block math uses). |

Both modes only take effect when `streamingAnimation` is `true`.

