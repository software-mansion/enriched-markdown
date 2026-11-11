---
sidebar_label: Markdown streaming
sidebar_position: 4
---

import StreamingSrc from '!!raw-loader!@site/src/examples/react-native/rich-text-formatting/markdown-streaming/Streaming';

# Markdown streaming

When Markdown arrives incrementally - token by token from an LLM, for example - you can render it as it streams instead of waiting for the whole string. The display component fades in newly appended text and handles half-formed block elements gracefully while the rest is still arriving.

:::note
Streaming ships in the React Native package, on iOS and Android. `streaming` and `streamingConfig` are stripped on web, where the current Markdown string renders without the fade-in animation or the incomplete-block handling below; a `stream` still shows its text as it grows.

The standalone iOS and Android packages have no streaming API. You can still hand them a growing Markdown string and each update renders it, but new text does not fade in and half-formed tables, code blocks and math are not held back.
:::

:::tip
Building an LLM chat UI? [`react-native-streamdown`](https://enriched.swmansion.com/streamdown) is a sibling library that wraps this renderer for streaming - it repairs incomplete Markdown on the fly and moves parsing off the JS thread, while accepting every `EnrichedMarkdownText` prop.

It is not quite a drop-in, though: it requires Worklets Bundle Mode, which means `bundleMode: true` plus `importForwarding` for `remend` in `babel.config.js`, a `getBundleModeMetroConfig` entry in `metro.config.js`, and a Metro patch - without which the one-shot `react-native bundle` used for offline release bundling fails. Read its README's **Required setup** section before adopting it.
:::

## Incremental rendering

Feed the growing Markdown string to the display component and set [`streaming`](/react-native/api-reference/enriched-markdown-text#streaming) while it arrives (off by default). Only the tail - the new characters beyond the previous content - fades in on each update, so the already-rendered text stays put. Set it back to `false` when the stream ends, so the final render shows everything:

```tsx
<EnrichedMarkdownText markdown={partialMarkdown} streaming={isStreaming} />
```

:::note
The tail is found by **length**, not by diffing: everything past the previous string's length fades in. Streaming therefore assumes **append-only** updates. If you replace `markdown` wholesale - a retry, a regeneration, switching to a different response - the fade will not line up with what actually changed.
:::

### Animations

New content animates in through [`streamingConfig.animation`](/react-native/api-reference/enriched-markdown-text#streamingconfig):

```tsx
// Each new word fades in over its own 200 ms (the default).
<EnrichedMarkdownText markdown={partial} streaming streamingConfig={{ animation: 'fade' }} />

// The last characters fade toward the end of the text, like a typewriter.
<EnrichedMarkdownText
  markdown={partial}
  streaming
  streamingConfig={{
    animation: { type: 'gradient', length: 15, startColor: '#107ACA', endColor: 'transparent' },
  }}
/>
```

- **`'fade'`** keeps time for each word on its own, so chunks arriving every frame still fade in fully, overlapping, and a word split across two chunks fades in as one. `duration` sets the time in milliseconds.
- **`'gradient'`** depends on each character's distance from the end, not on time: it follows the end of the text as it grows, and settles to the text's own colors over 200 ms when the stream ends. Without `startColor` each character keeps its own color (links, code, bold) and only fades toward the end.
- **`'none'`** shows new content at once; so does Reduce Motion.

Animations change only how characters are drawn, never the text, so selection, copy and accessibility see the text as it is. Blocks (tables, code blocks, images) fade in as a whole with `'fade'` and `'gradient'`.

### Smooth pacing

Models and networks deliver text in bursts. `streamingConfig.smooth` reveals it word by word at a steady pace instead, the way chat apps do:

```tsx
<EnrichedMarkdownText markdown={partial} streaming streamingConfig={{ smooth: true }} />
```

The view shows the text revealed so far, so lines, list items and blocks (tables, code blocks, images) grow with the words, and a view that scrolls to its end follows them line by line. Each chunk spreads over the time until the next one, so the pace follows the stream, at most a second behind; a word a chunk ends inside waits for the rest of it, and markdown such as a list marker or a heading's `##` waits for the word after it. When the stream ends, what is left shows within 200 ms. It works with every animation: words fade in with `'fade'`, the gradient follows the words, and with `'none'` words appear without fading. Reduce Motion keeps the pacing and turns off only the animation.

### Streaming without re-rendering

Passing a growing `markdown` re-renders your component on every chunk, and hands the whole text from JavaScript to native code each time. With a stream, your component doesn't re-render: append chunks to it, and the view updates once per frame on its own. Its text stays in native memory, so only each chunk crosses from JavaScript.

```tsx
import { createMarkdownStream } from 'react-native-enriched-markdown';

const stream = createMarkdownStream();
socket.onmessage = (event) => stream.append(event.data);
socket.onclose = () => stream.end();

<EnrichedMarkdownText stream={stream} flavor="github" />;
```

`end()` stops streaming and renders the whole text; `reset()` starts over for a retry. Keep the stream outside the component, so a row of a list that unmounts and mounts again shows the same text. See [`stream`](/react-native/api-reference/enriched-markdown-text#stream).

## Incomplete blocks

Some block elements can't be rendered until enough structure has arrived - a table needs its header and separator row, a fenced code block needs its closing fence. [`streamingConfig`](/react-native/api-reference/enriched-markdown-text#streamingconfig) decides what happens in the meantime.

:::note
This handling, and the inline repair below, applies while `streaming` is on, in both [flavors](/react-native/guides/markdown-flavors). Tables exist only in `github`, so `tableMode` has no effect under `commonmark`.
:::

**Tables** (`tableMode`)

| Mode | Behavior |
| --- | --- |
| `'progressive'` (default) | Renders the table row-by-row as content arrives; incomplete trailing rows are trimmed, and new rows fade in. |
| `'hidden'` | Withholds the table until it is complete (followed by a blank line), avoiding partially-formed-table jank. |

**Code blocks** (`codeBlockMode`)

| Mode | Behavior |
| --- | --- |
| `'progressive'` (default) | Streams the code line-by-line with a visible but non-interactive header (copying is disabled until the block completes); syntax highlighting is deferred until the closing fence so it does not flicker on every token. The block appears once the line that opens the fence has ended, so its language label never changes. |
| `'hidden'` | Withholds the whole block until its closing fence arrives, then shows it complete. |

A code block drawn by [`renderers.code`](/react-native/guides/custom-block-renderers#code-blocks) follows the same modes. In `'progressive'` its element re-renders with the growing code and receives `isComplete: false` until the closing fence arrives.

**Images, videos and links** (`mediaMode`)

| Mode | Behavior |
| --- | --- |
| `'progressive'` (default) | Shows a trailing image paragraph, link paragraph or `<video>` block once its syntax is complete. A half-streamed `![alt](https://…` or `[label](https://…` is withheld instead of flashing as text, and a partial `<video` tag is not shown. A bare URL on its own line can always grow, so it is withheld until the next line arrives. |
| `'hidden'` | Withholds the block until a blank line or another block follows it, like `tableMode: 'hidden'`. Applies to native images and to blocks drawn by [`renderers`](/react-native/guides/custom-block-renderers). |

**Block math** has no mode key. An unterminated `$$` block is always withheld, truncated at the opening delimiter, until the closing `$$` arrives. On a page of LLM output that routinely contains LaTeX, this is the third incomplete-block case to expect.

## Half-written inline syntax

Inline Markdown still being typed at the end is repaired, so it never flashes as raw syntax:

- emphasis, strikethrough and inline code get their closers: `**bold te` shows as **bold te**;
- a link shows its label as plain text until its URL is complete: `[docs](https://exa` shows as `docs`;
- an image, unclosed inline math (`$x^2`) and a lone marker line (`-`, `#`) wait until they can render.

Blocks that have finished are never touched again, so the cost of each update depends on the unfinished tail, not on the length of the document.

<LivePreview src={StreamingSrc} unavailable unavailableReason={<>iOS and Android only - <code>streaming</code> and <code>streamingConfig</code> are stripped on web.</>} />

## Reference

- [`streaming`](/react-native/api-reference/enriched-markdown-text#streaming) - set while the markdown is still arriving. Defaults to `false`. Replaces the deprecated `streamingAnimation`.
- [`stream`](/react-native/api-reference/enriched-markdown-text#stream) - markdown from `createMarkdownStream()`, updated once per frame without re-rendering your component.
- [`onStreamingEnd`](/react-native/api-reference/enriched-markdown-text#onstreamingend) - called when the view stops streaming, after the last words have appeared.
- [`streamingConfig`](/react-native/api-reference/enriched-markdown-text#streamingconfig) - `tableMode`, `codeBlockMode` and `mediaMode`, each `'progressive'` or `'hidden'`, and `animation`: `'fade'`, `'gradient'`, `'none'`, or a preset with its options. Needs `streaming`.
- [Markdown flavors](/react-native/guides/markdown-flavors) - what else the flavor switch changes.
- [`react-native-streamdown`](https://enriched.swmansion.com/streamdown) - sibling library for LLM output: incomplete-Markdown repair ([remend](https://www.npmjs.com/package/remend)) and off-thread processing (react-native-worklets Bundle Mode). Accepts every `EnrichedMarkdownText` prop plus a `remendConfig`: `<StreamdownText markdown={partial} />`. See the setup caveat above.
