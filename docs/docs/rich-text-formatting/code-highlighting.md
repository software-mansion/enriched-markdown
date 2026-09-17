---
sidebar_label: Code-block highlighting
sidebar_position: 3
---

# Code-block syntax highlighting

Fenced code blocks are syntax-highlighted natively via [tree-sitter](https://tree-sitter.github.io/). Highlighting is **foreground-only** - it recolors tokens and never changes text metrics, so a code block's measured height always matches its drawn height. It is on by default on iOS and Android with a curated set of languages, and can be trimmed or disabled to reduce binary size.

:::note
Syntax highlighting is a native feature - it is not available on the web build, where code blocks render as plain (uncolored) monospaced text.
:::

## Usage

Highlighting is driven by the **language tag on the opening fence** - the identifier written immediately after the opening ` ``` `, known as the _info string_. Tagging a block as `python` is what selects the grammar and colors it:

````markdown
```python
def greet(name):
    return f"Hi, {name}"
```
````

A block with **no** language tag, or one whose grammar is not [compiled in](#supported-languages), renders as plain, uncolored code - the tag is the switch. Set token colors through the `syntaxColors` map on the code-block style:

<CodeTabs groupId="platform">
<Tab label="React Native">

````tsx
<EnrichedMarkdownText
  flavor="github"
  markdown={String.raw`
\`\`\`python
def greet(name: str) -> str:
    return f"Hello, {name}!"  # a comment
\`\`\`
`}
  markdownStyle={{
    codeBlock: {
      syntaxColors: {
        keyword: '#C678DD',
        string: '#98C379',
        number: '#D19A66',
        comment: '#7F848E',
        function: '#61AFEF',
        type: '#E5C07B',
      },
    },
  }}
/>
````

</Tab>
<Tab label="iOS"><ComingSoon platform="iOS" /></Tab>
<Tab label="Android"><ComingSoon platform="Android" /></Tab>
</CodeTabs>

There are 14 token types, any of which you can color; a type left unset uses the normal code color: `keyword`, `operator`, `punctuation`, `string`, `number`, `constant`, `comment`, `function`, `type`, `variable`, `property`, `tag`, `attribute`, `embedded`.

## Supported languages

A fence's info string maps to a grammar (for example `js` and `jsx` both select JavaScript). A curated default set is compiled in unless you override it; a block whose language is not compiled simply renders as plain, uncolored code.

| Default (compiled in) | Opt-in (add explicitly) |
|---|---|
| json, html, css, markdown, yaml, go, java, javascript, python, c, rust, bash, typescript, tsx | cpp, swift, php, ruby, c-sharp |

The default set is the smaller-footprint tier; the opt-in grammars are heavier and only compiled when you list them explicitly.

## Copy button

With `flavor="github"`, each code block renders a header with a copy button (and a long-press menu offering **Copy** and **Copy as Markdown**). The `commonmark` flavor renders code blocks inline with no header, so it has no copy button. A copy callback fires whenever code is copied - via the header button, the long-press action, or the assistive-technology copy action - and the copy action's label is configurable. See the [Reference](#reference) for the exact callback and menu-config API.

## Reducing binary size

Only the grammars you compile end up in your binary, so trimming the language list is the main size lever - and because the highlighter degrades to plain code whenever a grammar is absent, nothing breaks when you remove one. You can also turn highlighting off entirely. The exact configuration is platform-specific - see the [Reference](#reference).

## How it works

Grammars and the tree-sitter runtime are vendored and compiled into the native build for exactly the languages you select, so the binary only references compiled grammars and the build stays offline and deterministic. The heavy grammar sources are not shipped in the npm package - they are downloaded once at install time (see your platform's setup). Highlighting runs synchronously when a block is applied and is cached per block, with a size cap (roughly 50 KB / 2000 lines) beyond which a block falls back to plain rendering.

## Reference

<CodeTabs groupId="platform">
<Tab label="React Native">

**Styling and callbacks**

- [`codeBlock.syntaxColors`](/react-native/api-reference/style-properties#syntax-colors) - the 14 token colors.
- [`onCopyPress`](/react-native/api-reference/enriched-markdown-text#oncopypress) - fires when code is copied.
- [`selectionMenuConfig`](/react-native/api-reference/enriched-markdown-text#selectionmenuconfig) - relabel or toggle the copy actions.

**Choosing languages / reducing binary size** - configure through the `enriched-markdown` block of your app's `package.json`:

```json
{
  "enriched-markdown": {
    "enableCodeHighlight": true,
    "codeHighlightLanguages": ["javascript", "tsx", "json", "bash"]
  }
}
```

`enableCodeHighlight` (default `true`) is the master switch; `codeHighlightLanguages` selects which grammars to compile - omit it for the curated default set, or pass `[]` to disable highlighting entirely. Re-run `pod install` (iOS) or rebuild (Android) after changing these; the same block works with Expo. See [Native assets](/react-native/guides/native-assets#reducing-binary-size) for the full opt-out.

</Tab>
<Tab label="iOS"><ComingSoon platform="iOS" /></Tab>
<Tab label="Android"><ComingSoon platform="Android" /></Tab>
</CodeTabs>
