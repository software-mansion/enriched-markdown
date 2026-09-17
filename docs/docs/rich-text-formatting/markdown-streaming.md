---
sidebar_label: Markdown streaming
sidebar_position: 4
---

# Markdown streaming

When Markdown arrives incrementally - token by token from an LLM, for example - you can render it as it streams instead of waiting for the whole string. The display component fades in newly appended text and handles half-formed block elements gracefully while the rest is still arriving.

:::note
Streaming is a native feature (iOS and Android). The web build renders the current Markdown string but without the fade-in animation or incomplete-block handling below.
:::

:::tip[TIP for React Native]
Building an LLM chat UI? [`react-native-streamdown`](https://www.npmjs.com/package/react-native-streamdown) is a sibling library that wraps this renderer for streaming - it repairs incomplete Markdown on the fly and moves parsing off the JS thread, while accepting every `EnrichedMarkdownText` prop. See the [Reference](#reference) for details.
:::

## Incremental rendering

Feed the growing Markdown string to the display component and enable `streamingAnimation`. Only the tail - the new characters beyond the previous content - animates on each update, so the already-rendered text stays put:

<CodeTabs groupId="platform">
<Tab label="React Native">

```tsx
<EnrichedMarkdownText markdown={partialMarkdown} streamingAnimation />
```

</Tab>
<Tab label="iOS"><ComingSoon platform="iOS" /></Tab>
<Tab label="Android"><ComingSoon platform="Android" /></Tab>
</CodeTabs>

## Incomplete blocks

With `flavor="github"`, some block elements can't be rendered until enough structure has arrived - a table needs its header and separator row, a fenced code block needs its closing fence. `streamingConfig` decides what happens in the meantime (it only takes effect while `streamingAnimation` is on):

**Tables** (`tableMode`)

| Mode                      | Behavior                                                                                                     |
| ------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `'progressive'` (default) | Renders the table row-by-row as content arrives; incomplete trailing rows are trimmed, and new rows fade in. |
| `'hidden'`                | Withholds the table until it is complete (followed by a blank line), avoiding partially-formed-table jank.   |

**Code blocks** (`codeBlockMode`)

| Mode                      | Behavior                                                                                                                                                                                                                |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `'progressive'` (default) | Streams the code line-by-line with a visible but non-interactive header (copying is disabled until the block completes); syntax highlighting is deferred until the closing fence so it does not flicker on every token. |
| `'hidden'`                | Withholds the whole block until its closing fence arrives, then shows it complete.                                                                                                                                      |

<CodeTabs groupId="platform">
<Tab label="React Native">

```tsx
<EnrichedMarkdownText
  markdown={partialMarkdown}
  flavor="github"
  streamingAnimation
  streamingConfig={{ tableMode: 'hidden', codeBlockMode: 'progressive' }}
/>
```

</Tab>
<Tab label="iOS"><ComingSoon platform="iOS" /></Tab>
<Tab label="Android"><ComingSoon platform="Android" /></Tab>
</CodeTabs>

## Reference

<CodeTabs groupId="platform">
<Tab label="React Native">

- [`streamingAnimation`](/react-native/api-reference/enriched-markdown-text#streaminganimation) - fade in newly appended content.
- [`streamingConfig`](/react-native/api-reference/enriched-markdown-text#streamingconfig) - `tableMode` and `codeBlockMode`, each `'progressive'` or `'hidden'`.
- [`react-native-streamdown`](https://www.npmjs.com/package/react-native-streamdown) - sibling library for LLM output: incomplete-Markdown repair ([remend](https://www.npmjs.com/package/remend)) and off-thread processing (react-native-worklets Bundle Mode). Accepts every `EnrichedMarkdownText` prop plus a `remendConfig`: `<StreamdownText markdown={partial} />`.

</Tab>
<Tab label="iOS"><ComingSoon platform="iOS" /></Tab>
<Tab label="Android"><ComingSoon platform="Android" /></Tab>
</CodeTabs>
