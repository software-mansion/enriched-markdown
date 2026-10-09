---
sidebar_label: Code-block highlighting
sidebar_position: 3
---

import SyntaxColorsSrc from '!!raw-loader!@site/src/examples/react-native/rich-text-formatting/code-highlighting/SyntaxColors';

# Code-block syntax highlighting

Fenced code blocks are syntax-highlighted natively via [tree-sitter](https://tree-sitter.github.io/). Highlighting is **foreground-only** - it recolors tokens and never changes text metrics, so a code block's measured height always matches its drawn height. In the React Native package it is on by default on iOS and Android with a curated set of languages, and can be trimmed or disabled to reduce binary size.

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

A block with **no** language tag, or one whose grammar is not [compiled in](#supported-languages), renders as plain, uncolored code - the tag is the switch.

Highlighting itself is **independent of the [flavor](/react-native/guides/markdown-flavors)**: it works the same under `commonmark` and `github`. Only the header bar and copy button below need `flavor="github"`.

Set token colors through the `syntaxColors` map on the code-block style:

<LivePreview src={SyntaxColorsSrc} unavailable unavailableReason={<>iOS and Android only - the web build renders code blocks uncolored, so <code>syntaxColors</code> has no visible effect here.</>} />

There are 14 token types, any of which you can color. Most of them ship with a color of their own, from a GitHub-dark palette tuned for the default `#1F2937` code background:

| Token | Default |
| --- | --- |
| `keyword` | `#FF7B72` |
| `string` | `#A5D6FF` |
| `number`, `constant`, `property`, `attribute` | `#79C0FF` |
| `comment` | `#8B949E` |
| `function` | `#D2A8FF` |
| `type` | `#FFA657` |
| `tag` | `#7EE787` |
| `operator`, `punctuation`, `variable`, `embedded` | inherit `codeBlock.color` |

Only those last four fall back to the normal code color when left unset; the other ten keep their palette default until you override them.

## Supported languages

A fence's info string maps to a grammar (for example `js` and `jsx` both select JavaScript). A curated default set is compiled in unless you override it; a block whose language is not compiled simply renders as plain, uncolored code.

| Default (compiled in) | Opt-in (add explicitly) |
|---|---|
| json, html, css, markdown, yaml, go, java, javascript, python, c, rust, bash, typescript, tsx | cpp, swift, php, ruby, c-sharp |

The default set is the smaller-footprint tier; the opt-in grammars are heavier and only compiled when you list them explicitly.

Several fence tags are aliases of the same grammar - `sh`, `shell` and `zsh` all select `bash`; `cc`, `cpp` and `cxx` select `cpp`; `cs` and `csharp` select `c-sharp`; and likewise `golang`, `js`/`jsx`, `md`, `py`, `rb`, `rs`, `ts`, `yml`. A handful of tags are recognized as **labels only** and never highlighted: `dockerfile`, `graphql`, `objc`, `objectivec`, `scss`, `sql`, `toml`, `xml`.

:::caution
The alias table and the `codeHighlightLanguages` ids are **not** the same list. `c-sharp` is the grammar id you must write in `codeHighlightLanguages`, but it is not a valid fence tag - in Markdown, write `cs` or `csharp`.
:::

## Copy button

Under [`flavor="github"`](/react-native/guides/markdown-flavors), a code block is rendered as its own block component and carries a header with the language label and a **copy button**, backed by a long-press menu offering **Copy** and **Copy as Markdown**.

[`onCopyPress`](/react-native/api-reference/enriched-markdown-text#oncopypress) fires for the header button, the long-press **Copy** action, and the assistive-technology copy action. It does **not** fire for **Copy as Markdown**, which copies the code without reporting it.

:::note
Under the default `flavor="commonmark"` the whole document is drawn as a single text view, where a code block is inline text with no header - and therefore no copy button. The web build has no header or copy button either, in either flavor, so `onCopyPress` can never fire there.
:::

{/* UNRELEASED PLATFORMS: when the standalone iOS and Android SDKs ship, note
that neither highlights code or renders a code-block header or copy button -
their code-block renderers set font and color on a text range. The standalone
iOS SDK does vend a VoiceOver "Copy code" action. */}

## Reducing binary size

Only the grammars you compile end up in your binary, so trimming the language list is the main size lever - and because the highlighter degrades to plain code whenever a grammar is absent, nothing breaks when you remove one. You can also turn highlighting off entirely.

## How it works

Grammars and the tree-sitter runtime are vendored and compiled into the native build for exactly the languages you select, so the binary only references compiled grammars and the build stays offline and deterministic. The heavy grammar sources are not shipped in the npm package - they are [downloaded once at install time](/react-native/guides/native-assets#install-time-native-downloads).

Highlighting runs synchronously when a block is applied, with a size cap (roughly 50 KB / 2000 lines) beyond which a block falls back to plain rendering. What is cached is the compiled highlight query per grammar, not the tokens of a given block - under `flavor="github"` an unchanged block keeps its view, which is what avoids the re-work in practice. While a fence is still unclosed during [streaming](/rich-text-formatting/markdown-streaming), highlighting is deferred until the closing fence arrives.

## Reference

**Styling and callbacks**

- [`codeBlock.syntaxColors`](/react-native/api-reference/style-properties#syntax-colors) - the 14 token colors.
- [`onCopyPress`](/react-native/api-reference/enriched-markdown-text#oncopypress) - fires when code is copied.
- [`selectionMenuConfig`](/react-native/api-reference/enriched-markdown-text#selectionmenuconfig) - relabel or toggle the copy actions.
- [`enableBlockContextMenu`](/react-native/api-reference/enriched-markdown-text#enableblockcontextmenu) - turn the long-press menu off without touching the header button.

**Choosing languages / reducing binary size** - configure through the `enriched-markdown` block of your app's `package.json`:

```json
{
  "enriched-markdown": {
    "enableCodeHighlight": true,
    "codeHighlightLanguages": ["javascript", "tsx", "json", "bash"]
  }
}
```

`enableCodeHighlight` (default `true`) is the master switch; `codeHighlightLanguages` selects which grammars to compile - omit it for the curated default set, or pass `[]` to disable highlighting entirely. Re-run `pod install` (iOS) or rebuild (Android) after changing these. See [Native assets](/react-native/guides/native-assets#reducing-binary-size) for the full opt-out.

:::danger
`codeHighlightLanguages` takes **grammar ids**, not fence tags, and an unknown id is a hard error rather than a silent skip: the generator exits non-zero and the podspec raises, so a typo or an alias such as `"csharp"` instead of `"c-sharp"` **fails the build**.
:::

:::note
The same block works with Expo, but these are compile-time settings baked into the native build, so they cannot take effect in Expo Go. Use a [development build](https://docs.expo.dev/develop/development-builds/introduction/).
:::
