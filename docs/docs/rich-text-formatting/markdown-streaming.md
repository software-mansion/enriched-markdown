---
sidebar_label: Markdown streaming
sidebar_position: 5
---

import StreamingSrc from '!!raw-loader!@site/src/examples/react-native/rich-text-formatting/markdown-streaming/Streaming';

# Markdown streaming

When Markdown arrives incrementally - token by token from an LLM, for example - you can render it as it streams instead of waiting for the whole string. The display component fades in newly appended text and handles half-formed block elements gracefully while the rest is still arriving.

:::note
Streaming ships in the React Native package, on iOS and Android. Both props are stripped on web, where the current Markdown string renders without the fade-in animation or the incomplete-block handling below.
:::

:::tip
Building an LLM chat UI? [`react-native-streamdown`](https://enriched.swmansion.com/streamdown) is a sibling library that wraps this renderer for streaming - it repairs incomplete Markdown on the fly and moves parsing off the JS thread, while accepting every `EnrichedMarkdownText` prop.

It is not quite a drop-in, though: it requires Worklets Bundle Mode, which means `bundleMode: true` plus `importForwarding` for `remend` in `babel.config.js`, a `getBundleModeMetroConfig` entry in `metro.config.js`, and a Metro patch - without which the one-shot `react-native bundle` used for offline release bundling fails. Read its README's **Required setup** section before adopting it.
:::

## Incremental rendering

Feed the growing Markdown string to the display component and enable [`streamingAnimation`](/react-native/api-reference/enriched-markdown-text#streaminganimation) (off by default). Only the tail - the new characters beyond the previous content - animates on each update, so the already-rendered text stays put:

```tsx
<EnrichedMarkdownText markdown={partialMarkdown} streamingAnimation />
```

:::note
The tail is found by **length**, not by diffing: everything past the previous string's length fades in. Streaming therefore assumes **append-only** updates. If you replace `markdown` wholesale - a retry, a regeneration, switching to a different response - the fade will not line up with what actually changed.
:::

## Incomplete blocks

Some block elements can't be rendered until enough structure has arrived - a table needs its header and separator row, a fenced code block needs its closing fence. [`streamingConfig`](/react-native/api-reference/enriched-markdown-text#streamingconfig) decides what happens in the meantime.

:::caution
It takes **two** conditions, not one: `streamingAnimation` must be on **and** the flavor must be [`github`](/react-native/guides/markdown-flavors). The filter runs only on the segmented renderer, so under the default `flavor="commonmark"` you get the tail fade and nothing else - `streamingConfig` is inert there. This is worth knowing because `streamingAnimation` is otherwise most natural with `commonmark`.
:::

**Tables** (`tableMode`)

| Mode | Behavior |
| --- | --- |
| `'progressive'` (default) | Renders the table row-by-row as content arrives; incomplete trailing rows are trimmed, and new rows fade in. |
| `'hidden'` | Withholds the table until it is complete (followed by a blank line), avoiding partially-formed-table jank. |

**Code blocks** (`codeBlockMode`)

| Mode | Behavior |
| --- | --- |
| `'progressive'` (default) | Streams the code line-by-line with a visible but non-interactive header (copying is disabled until the block completes); syntax highlighting is deferred until the closing fence so it does not flicker on every token. |
| `'hidden'` | Withholds the whole block until its closing fence arrives, then shows it complete. |

**Block math** has no mode key. An unterminated `$$` block is always withheld, truncated at the opening delimiter, until the closing `$$` arrives. On a page of LLM output that routinely contains LaTeX, this is the third incomplete-block case to expect.

<LivePreview src={StreamingSrc} unavailable unavailableReason={<>iOS and Android only - <code>streamingAnimation</code> and <code>streamingConfig</code> are stripped on web.</>} />

{/* UNRELEASED PLATFORMS: neither standalone SDK has any streaming API. When
they ship, these sections need per-platform tabs rather than the ComingSoon
placeholders they previously carried, which implied the feature existed. */}

## Reference

- [`streamingAnimation`](/react-native/api-reference/enriched-markdown-text#streaminganimation) - fade in newly appended content. Defaults to `false`.
- [`streamingConfig`](/react-native/api-reference/enriched-markdown-text#streamingconfig) - `tableMode` and `codeBlockMode`, each `'progressive'` or `'hidden'`. Needs `streamingAnimation` **and** `flavor="github"`.
- [Markdown flavors](/react-native/guides/markdown-flavors) - what else the flavor switch changes.
- [`react-native-streamdown`](https://enriched.swmansion.com/streamdown) - sibling library for LLM output: incomplete-Markdown repair ([remend](https://www.npmjs.com/package/remend)) and off-thread processing (react-native-worklets Bundle Mode). Accepts every `EnrichedMarkdownText` prop plus a `remendConfig`: `<StreamdownText markdown={partial} />`. See the setup caveat above.
