---
sidebar_label: Markdown streaming
sidebar_position: 4
---

import StreamingSrc from '!!raw-loader!@site/src/examples/react-native/rich-text-formatting/markdown-streaming/Streaming';

# Markdown streaming

When Markdown arrives incrementally - token by token from an LLM, for example - you can render it as it streams instead of waiting for the whole string. The display component fades in newly appended text and handles half-formed block elements gracefully while the rest is still arriving.

:::note
Streaming ships in the React Native package, on iOS and Android. `streaming` and `streamingConfig` are stripped on web, where the current Markdown string renders without the fade-in animation or the incomplete-block handling below.

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
- [`onStreamingEnd`](/react-native/api-reference/enriched-markdown-text#onstreamingend) - called when the view stops streaming.
- [`streamingConfig`](/react-native/api-reference/enriched-markdown-text#streamingconfig) - `tableMode`, `codeBlockMode` and `mediaMode`, each `'progressive'` or `'hidden'`, and `animation`, `'fade'` or `'none'`. Needs `streaming`.
- [Markdown flavors](/react-native/guides/markdown-flavors) - what else the flavor switch changes.
- [`react-native-streamdown`](https://enriched.swmansion.com/streamdown) - sibling library for LLM output: incomplete-Markdown repair ([remend](https://www.npmjs.com/package/remend)) and off-thread processing (react-native-worklets Bundle Mode). Accepts every `EnrichedMarkdownText` prop plus a `remendConfig`: `<StreamdownText markdown={partial} />`. See the setup caveat above.
