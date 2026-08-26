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
`operator`, `punctuation`, `string`, `number`, `constant`, `comment`, `function`, `type`,
`variable`, `property`, `tag`, `attribute`, `embedded`. Any type left unset is drawn in the normal
code color.

## Copy button

With `flavor="github"`, each code block's header shows a copy button (and a long-press context
menu with **Copy** / **Copy as Markdown**). The CommonMark flavor renders code blocks inline with
no header, so it has no copy button. To observe when a user copies code, pass
[`onCopyPress`](./API_REFERENCE.md#oncopypress) — it fires with the copied `code` and its
`language` for the header button, the context-menu **Copy** action, and the VoiceOver copy action.
The copy label shown to assistive technologies is configurable via
[`selectionMenuConfig`](./COPY_OPTIONS.md).

## Supported languages

Fence info strings map to a grammar (for example `js` and `jsx` both select JavaScript). The **curated default
set** is compiled in unless you override it. It is defined by `default:true` in
`vendor/grammar-versions.json` (the single source of truth the iOS podspec and Android build both
derive from), so the table below tracks that manifest:

| Default (on) | Opt-in (heavier) |
|---|---|
| json, html, css, markdown, yaml, go, java, javascript, python, c, rust, bash, typescript, tsx | cpp, swift, php, ruby, c-sharp |

The default set is the smaller-footprint tier (~32 MB of grammar C source across the whole set).
The opt-in grammars are larger (17-29 MB each) and are only compiled when you list them explicitly.
A block whose language is not compiled in simply renders as plain (uncolored) code.

## Choosing languages / reducing binary size

Only the grammars you compile end up in your binary, so trimming the list is the main size lever.
The seam degrades to plain code whenever a grammar is absent, so nothing breaks when you remove one.

Configure everything through the `enriched-markdown` block of your app's `package.json` — it is the
single source of truth for both platforms and both the install-time download and the build:

```json
{
  "enriched-markdown": {
    "enableCodeHighlight": true,
    "codeHighlightLanguages": ["javascript", "tsx", "json", "bash"]
  }
}
```

How the two keys interact:

- **`enableCodeHighlight`** (default `true`) is the master switch. When `false`, the grammar download is
  skipped **and** the tree-sitter runtime is excluded from the native build. In that state
  **`codeHighlightLanguages` is ignored — it is a no-op**, because there is no highlighter compiled in for
  languages to feed.
- **`codeHighlightLanguages`** selects which grammars to compile *when highlighting is enabled*. Omit it
  for the curated default set, or pass a subset to shrink the binary. An empty array (`[]`) compiles no
  grammars, which disables highlighting entirely — equivalent to `enableCodeHighlight: false`.

Re-run `pod install` (iOS) / rebuild (Android) after changing these. The same block works with Expo —
`node_modules` survives `npx expo prebuild`, so no config plugin is needed (highlighting is compiled in,
so it can't be changed in **Expo Go**; use a dev client or `expo prebuild`). See
[Skipping the download](./NATIVE_ASSETS.md#skipping-the-download-opt-out).

> [!NOTE]
> **Deprecated:** the `ENV['ENRICHED_MARKDOWN_*']` Podfile variables and the `enrichedMarkdown.*` gradle
> properties still work as a fallback but are deprecated and print a warning; they are ignored when the
> corresponding `package.json` key is set. The Expo config plugin was removed — see
> [Breaking changes](./BREAKING_CHANGES.md). Prefer the `package.json` block above.

## How it works

Grammars are **vendored** into `packages/core/cpp/highlight/vendor/` (only each grammar's
`parser.c`/`scanner.c` + `highlights.scm`, never whole npm packages), so the native build itself is
fully offline and deterministic. The stable tree-sitter runtime is vendored the same way and compiled
with WebAssembly support left out. A build-time codegen emits a registry for exactly the selected
languages, so the binary and link step only ever reference compiled grammars.

The entire `vendor/` tree is **gitignored** to keep the repo and PRs small — nothing generated lives
in git. `vendor/vendor-grammars.mjs` restores all of it from the pins in `vendor/grammar-versions.json`:
the tree-sitter runtime (`vendor/tree-sitter/`) is fetched and sha256-verified from the pinned GitHub
release tarball, the ~178 MB of grammar `parser.c` tables (`vendor/grammars/`) are copied from the
pinned grammar devDependencies, and the default registry (`vendor/generated/`) is codegen'd from them.
It is wired into the package `prepare` script (so a plain `yarn install` restores everything, with
`.stamp` guards making repeats a no-op).

The published npm tarball ships only the small default registry, **not** the heavy grammar/runtime
source — that would bloat every install to ~230 MB. Instead a `postinstall` script downloads the
grammar sources (from the npm registry) and the tree-sitter runtime (from the pinned GitHub release)
into the installed package, sha256-verified and idempotent. See [Native assets](./NATIVE_ASSETS.md)
for the install-time behavior, network requirements, and how to recover an offline/pnpm install.

Highlighting runs synchronously when a code block is applied and is cached per block, with a size cap
(~50 KB / ~2000 lines) that falls back to plain rendering for pathological inputs. Maintainers re-pin
by editing `vendor/grammar-versions.json` (for a runtime bump, also update `runtime.sha256` — a full
`node vendor/vendor-grammars.mjs --force` run prints the correct digest on mismatch) and re-running
the script; there is nothing generated to commit. To vendor the runtime from a local tree-sitter
checkout instead of the network, pass `--runtime-src <path to tree-sitter/lib>` (or set
`TREE_SITTER_SRC`).
