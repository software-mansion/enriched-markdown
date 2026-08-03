# Code-block syntax highlighting

Fenced code blocks are syntax-highlighted natively via [tree-sitter](https://tree-sitter.github.io/).
Highlighting is **foreground-only** (it recolors tokens and never changes text metrics), so a code
block's measured height always matches its drawn height. It is enabled by default on iOS and Android
with a curated set of languages, and can be trimmed or disabled to reduce binary size.

## Usage

Highlighting activates automatically for a fenced block whose info string names a supported language:

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
        // ...any of the 14 token types
      },
    },
  }}
/>
````

Token colors are set through `codeBlock.syntaxColors`. The 14 token types are: `keyword`,
`operatorColor`, `punctuation`, `string`, `number`, `constant`, `comment`, `function`, `type`,
`variable`, `property`, `tag`, `attribute`, `embedded`. Any type left unset is drawn in the normal
code color.

## Supported languages

Fence info strings map to a grammar (for example `js`, `jsx` -> JavaScript). The **curated default
set** is compiled in unless you override it:

| Default (on) | Opt-in (heavier) |
|---|---|
| json, html, css, markdown, yaml, go, java, javascript, python, c, rust, bash | typescript, tsx, cpp, swift, kotlin, php, ruby, c-sharp |

The default set is the smaller-footprint tier (~32 MB of grammar C source across the whole set).
The opt-in grammars are larger (17-29 MB each) and are only compiled when you list them explicitly.
A block whose language is not compiled in simply renders as plain (uncolored) code.

## Choosing languages / reducing binary size

Only the grammars you compile end up in your binary, so trimming the list is the main size lever.
The seam degrades to plain code whenever a grammar is absent, so nothing breaks when you remove one.

### iOS

Add to your `Podfile` and re-run `pod install`:

```ruby
# Compile a custom set (comma-separated; adds tsx to the trimmed set below):
ENV['ENRICHED_MARKDOWN_CODE_HIGHLIGHT_LANGUAGES'] = 'javascript,tsx,json,bash'

# ...or disable highlighting entirely (no tree-sitter code linked):
ENV['ENRICHED_MARKDOWN_ENABLE_CODE_HIGHLIGHT'] = '0'
```

### Android

Add to your project's `gradle.properties`:

```properties
# Compile a custom set:
enrichedMarkdown.codeHighlightLanguages=javascript,tsx,json,bash

# ...or disable highlighting entirely:
enrichedMarkdown.enableCodeHighlight=false
```

Rebuild the app after changing either value.

### Expo config plugin

Configure both platforms at once in `app.json` / `app.config.js`:

```json
{
  "expo": {
    "plugins": [
      [
        "react-native-enriched-markdown",
        {
          "codeHighlight": {
            "enabled": true,
            "languages": ["javascript", "tsx", "json", "bash"]
          }
        }
      ]
    ]
  }
}
```

Set `"enabled": false` to disable it. Changes are applied during `npx expo prebuild`; if you change
the set later, run `npx expo prebuild --clean` and rebuild.

## How it works

Grammars are **vendored** into `packages/core/cpp/highlight/vendor/` (only each grammar's
`parser.c`/`scanner.c` + `highlights.scm`, never whole npm packages), so builds are fully offline and
deterministic. The stable tree-sitter runtime is vendored the same way and compiled with WebAssembly
support left out. A build-time codegen emits a registry for exactly the selected languages, so the
binary and link step only ever reference compiled grammars.

The ~34 MB of generated grammar `parser.c` tables (`vendor/grammars/`) are **gitignored** to keep the
repo and PRs small. They are regenerated from the pinned grammar devDependencies by
`vendor/vendor-grammars.mjs --grammars-only`, which is wired into the package `prepare` script (so a
plain `yarn install` restores them, with a `.stamp` guard making repeats a no-op) and into `prepack`
(so the published npm tarball still ships the full set). The small tree-sitter runtime
(`vendor/tree-sitter/`) and the committed default registry (`vendor/generated/`) stay tracked in git.

Highlighting runs synchronously when a code block is applied and is cached per block, with a size cap
(~50 KB / ~2000 lines) that falls back to plain rendering for pathological inputs. Maintainers
re-pin, refresh the runtime, and regenerate the committed registry with a full
`node vendor/vendor-grammars.mjs` run (requires the tree-sitter runtime source via `--runtime-src` or
`TREE_SITTER_SRC`) after editing `vendor/grammar-versions.json`, then commit the runtime + registry.
