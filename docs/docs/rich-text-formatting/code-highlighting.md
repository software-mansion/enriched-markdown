---
sidebar_label: Code-block highlighting
sidebar_position: 3
---

import SyntaxColorsSrc from '!!raw-loader!@site/src/examples/react-native/rich-text-formatting/code-highlighting/SyntaxColors';

# Code-block syntax highlighting

Fenced code blocks are syntax-highlighted natively via [tree-sitter](https://tree-sitter.github.io/). Highlighting is **foreground-only** - it recolors tokens and never changes text metrics, so a code block's measured height always matches its drawn height. In the React Native package it is on by default on iOS and Android with a curated set of languages, and can be trimmed or disabled to reduce binary size. The standalone iOS SDK ships it as an optional product you enable per view, and the standalone Android SDK as an optional artifact you enable with a plugin - see [iOS and Android SDKs](#ios-and-android-sdks).

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

Highlighting itself is **independent of the [flavor](/react-native/guides/markdown-flavors)**: it works the same under `commonmark` and `github`. In the React Native package, only the header bar and copy button below need `flavor="github"`.

In the React Native package, set token colors through the `syntaxColors` map on the code-block style:

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

A fence's info string maps to a grammar (for example `js` and `jsx` both select JavaScript). In the React Native package a curated default set is compiled in unless you override it; a block whose language is not compiled simply renders as plain, uncolored code.

| Default (compiled in) | Opt-in (add explicitly) |
|---|---|
| json, html, css, markdown, yaml, go, java, javascript, python, c, rust, bash, typescript, tsx | cpp, swift, php, ruby, c-sharp |

The default set is the smaller-footprint tier; the opt-in grammars are heavier and only compiled when you list them explicitly.

Several fence tags are aliases of the same grammar - `sh`, `shell` and `zsh` all select `bash`; `cc`, `cpp` and `cxx` select `cpp`; `cs` and `csharp` select `c-sharp`; and likewise `golang`, `js`/`jsx`, `md`, `py`, `rb`, `rs`, `ts`, `yml`. A handful of tags are recognized as **labels only** and never highlighted: `dockerfile`, `graphql`, `objc`, `objectivec`, `scss`, `sql`, `toml`, `xml`.

:::caution
The alias table and the `codeHighlightLanguages` ids are **not** the same list. `c-sharp` is the grammar id you must write in `codeHighlightLanguages`, but it is not a valid fence tag - in Markdown, write `cs` or `csharp`.
:::

## Copy button

In the React Native package, under [`flavor="github"`](/react-native/guides/markdown-flavors), a code block is rendered as its own block component and carries a header with the language label and a **copy button**, backed by a long-press menu offering **Copy** and **Copy as Markdown**.

[`onCopyPress`](/react-native/api-reference/enriched-markdown-text#oncopypress) fires for the header button, the long-press **Copy** action, and the assistive-technology copy action. It does **not** fire for **Copy as Markdown**, which copies the code without reporting it.

:::note
Under the default `flavor="commonmark"` the whole document is drawn as a single text view, where a code block is inline text with no header - and therefore no copy button. The web build has no header or copy button either, in either flavor, so `onCopyPress` can never fire there.
:::

## iOS and Android SDKs {#ios-and-android-sdks}

The standalone native SDKs are configured in code rather than through `package.json`, and differ from the React Native package in a few ways.

**iOS** - highlighting is the optional `EnrichedMarkdownSyntaxHighlighting` product, and it is **off** until you enable it per view with [`.markdownSyntaxHighlighting()`](/ios/guides/syntax-highlighting#markdownsyntaxhighlighting) (it takes a `Bool`, so `.markdownSyntaxHighlighting(false)` turns it back off for a subtree). Outside SwiftUI, `MarkdownRenderer.renderSyntaxHighlighted` [renders a string with highlighting installed](/ios/guides/syntax-highlighting#rendering-without-a-view). Compared with the React Native package:

- The grammar set is fixed at the 14 [default languages](#supported-languages) above - there is nothing to trim or add, and the opt-in grammars are not available.
- Token colors are [`SyntaxToken(_:)`](/ios/api-reference/style-properties#syntaxtoken) theme elements. The default `.syntaxHighlightingDefault` palette is GitHub's and [adapts to light and dark mode](/ios/guides/syntax-highlighting#default-palette).
- The tokens of each block are [cached](/ios/guides/syntax-highlighting#caching), so a re-render that leaves a block's code unchanged does not parse it again. Blocks over 50 KB or 2,000 lines stay plain.
- The header bar and copy button are independent of highlighting and of any flavor: [`.markdownCodeBlockLayout(.scrollable)`](/ios/api-reference/enriched-markdown-text#markdowncodeblocklayout) renders each block as a panel with a language header, a copy button and a long-press **Copy** / **Copy as Markdown** menu. [`.onCodeBlockCopy { }`](/ios/api-reference/enriched-markdown-text#oncodeblockcopy) fires for the button, the long-press **Copy** action and the VoiceOver "Copy code" action, never for **Copy as Markdown**.

See the [iOS syntax highlighting guide](/ios/guides/syntax-highlighting) for the full setup.

**Android** - highlighting is the optional `com.swmansion.enriched.markdown:code-highlight` artifact, and it does nothing until you enable `CodeHighlightPlugin` - as a Compose scope (`CodeHighlightPlugin { }`, or `MarkdownPlugins(...)` together with other plugins) or per instance through the `plugins` parameter. Compared with the React Native package:

- The grammar set is fixed at the same 14 [default languages](#supported-languages) - there is nothing to trim or add, and the opt-in grammars are not available. Info strings match case-insensitively.
- Token colors are set with the `codeHighlight { }` block of `markdownStyle`. The default palette is GitHub's dark one and does **not** follow light or dark mode: if you give `codeBlock` a light background, set the token colors too.
- The tokens of each block are cached, so a re-render that leaves a block's code unchanged - a lazy list item scrolled back into view, a configuration change - does not parse it again. Blocks over 50 KB or 2,000 lines stay plain.
- There is no code-block header or copy button: a highlighted block is drawn like a plain one, only recolored.

See the [Android code highlighting guide](/android/guides/code-highlighting) for the full setup.


## Reducing binary size

In the React Native package, only the grammars you compile end up in your binary, so trimming the language list is the main size lever - and because the highlighter degrades to plain code whenever a grammar is absent, nothing breaks when you remove one. You can also turn highlighting off entirely. On the standalone SDKs the size lever is the optional module itself: leave out `EnrichedMarkdownSyntaxHighlighting` (iOS) or the `code-highlight` artifact (Android) and no grammar ships. On Android the artifact's native library is about 8 MB per ABI uncompressed (what an installed app carries) and about 1.1 MB per ABI compressed (roughly what it adds to a download).

## How it works

In the React Native package, grammars and the tree-sitter runtime are vendored and compiled into the native build for exactly the languages you select, so the binary only references compiled grammars and the build stays offline and deterministic. The heavy grammar sources are not shipped in the npm package - they are [downloaded once at install time](/react-native/guides/native-assets#install-time-native-downloads).

Highlighting runs synchronously when a block is applied, with a size cap (roughly 50 KB / 2000 lines) beyond which a block falls back to plain rendering. What is cached is the compiled highlight query per grammar, not the tokens of a given block - under `flavor="github"` an unchanged block keeps its view, which is what avoids the re-work in practice. While a fence is still unclosed during [streaming](/rich-text-formatting/markdown-streaming), highlighting is deferred until the closing fence arrives.

## Reference

**Styling and callbacks**

- [`codeBlock.syntaxColors`](/react-native/api-reference/style-properties#syntax-colors) - the 14 token colors.
- [`onCopyPress`](/react-native/api-reference/enriched-markdown-text#oncopypress) - fires when code is copied.
- [`selectionMenuConfig`](/react-native/api-reference/enriched-markdown-text#selectionmenuconfig) - relabel or toggle the copy actions.
- [`enableBlockContextMenu`](/react-native/api-reference/enriched-markdown-text#enableblockcontextmenu) - turn the long-press menu off without touching the header button.

**iOS**

- [`.markdownSyntaxHighlighting(_:)`](/ios/guides/syntax-highlighting#markdownsyntaxhighlighting) - enable or disable highlighting per view.
- [`SyntaxToken(_:)`](/ios/api-reference/style-properties#syntaxtoken) - the 14 token colors.
- [`.markdownCodeBlockLayout(.scrollable)`](/ios/api-reference/enriched-markdown-text#markdowncodeblocklayout) - the header bar and copy button.
- [`.onCodeBlockCopy`](/ios/api-reference/enriched-markdown-text#oncodeblockcopy) - fires when code is copied.

**Android**

- [`CodeHighlightPlugin`](/android/guides/code-highlighting) - enable highlighting for a Compose subtree or a single instance.
- [`codeHighlight { }`](/android/guides/code-highlighting) - the 14 token colors, set in `markdownStyle`.

**Choosing languages / reducing binary size (React Native package)** - configure through the `enriched-markdown` block of your app's `package.json`:

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
