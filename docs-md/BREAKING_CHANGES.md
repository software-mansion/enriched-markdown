# Breaking changes

This file tracks breaking changes and how to migrate for each. Entries are newest first. Deprecations
(things that still work but are slated for removal) are noted alongside the change that introduces them.

## Unreleased

### EnrichedMarkdownTextInput on iOS and Android writes and reads markdown with the shared web rules

`getMarkdown()`, `onChangeMarkdown`, copy and `setValue()` now go through one implementation shared with the web
input, so a value saved on one platform loads unchanged on another. Documents still load; only a value that is
re-saved can come out different from what the previous version stored. If your app compares saved strings (dirty
checks, sync), expect one diff the first time a document is re-saved.

What changes in the markdown the input writes:

- Plain text that would read as markup is escaped: `*`, `_`, `~`, `|`, `[`, `]`, `` ` ``, `<`, `\`, `&` before an
  entity, `#`, `-`, `+`, `>` and `1.` at the start of a line, trailing `#` runs, and `!` before a link. `2 *x* 6`
  is saved as `2 \*x\* 6`, and a heading titled `Use #` as `## Use \#`. Previously this text came back as
  formatting after a reload.
- Link destinations are escaped, and wrapped in `<...>` when they contain whitespace or unbalanced parentheses.
- A delimiter next to a word character is written so it still reads as formatting (`***a***bcd`).
- Link and spoiler are written outside bold, italic, underline and strikethrough over the same text:
  `[**docs**](url)` instead of `**[docs](url)**`.
- Nested list items indent by the width of their parent's marker (`- ` is 2 columns, `1. ` is 3, `10. ` is 4)
  instead of 3 columns per level.
- Spaces after a list marker are kept as text (`1.  x`) instead of collapsing to one.
- Text such as `- > x` (a list item that starts with a quote marker) is saved as `- \> x`; it is no longer stripped.

What changes in how markdown is read:

- An unclosed `*`, `_`, `~~`, `||` or `[` stays literal text. It used to be closed automatically, and an unclosed
  `[` dropped the rest of its block. `## Title [wip` followed by a paragraph now loads as both.
- Quotes, code spans, code blocks, tables and rules lose their markers and keep their content as plain lines
  (`> quote` loads as `quote`). iOS used to keep the raw characters as text, so they survived a save; they no
  longer do.
- A list item with no text is kept (`- a`, `- `, `- c` loads as three items) instead of being dropped.
- Blank lines between blocks are kept as empty lines, one per blank line.
- On Android, an empty list item loaded this way shows its marker right away, like one created by pressing Enter.
  Copying part of an ordered list keeps the numbers (items 3 and 4 copy as `3.` and `4.`).

**Migrate:** nothing is required. If you store markdown and compare it, re-save once, or compare the parsed value.

## v1.1.1

No breaking changes. v1.1.1 is a patch release over v1.1.0 - every public prop, method, event and style
key from v1.1.0 keeps its name and behaviour, and no deprecation was introduced or removed.

## v1.1.0

No breaking changes. v1.1.0 is additive over v1.0.2 - every public prop, method, event and style key
from v1.0.2 keeps its name and behaviour, and no deprecation was introduced or removed.

## v1.0.2

### The Expo config plugin was removed

The built-in Expo config plugin (`app.plugin.js` and the `plugin/` folder) has been removed. Feature
configuration now lives entirely in your app's `package.json`, read directly by the native build and by
`postinstall` — the same approach `react-native-worklets` uses for its static feature flags.

Why: the plugin only wrote the (now deprecated) Podfile `ENV` / `gradle.properties` channels, it could
never influence the install-time asset download (it runs during `expo prebuild`, _after_ `npm install`),
and its option shape diverged from the `package.json` block. The `package.json` block supersedes it for
both the download and the build, and it survives `expo prebuild`.

**Migrate:** remove the plugin entry from `app.json` / `app.config.js` and move the options into the
`enriched-markdown` block of your `package.json`.

Before (`app.json`):

```json
{
  "expo": {
    "plugins": [
      [
        "react-native-enriched-markdown",
        {
          "enableMath": false,
          "codeHighlight": {
            "enabled": true,
            "languages": ["javascript", "tsx"]
          }
        }
      ]
    ]
  }
}
```

After (`package.json`):

```json
{
  "enriched-markdown": {
    "enableMath": false,
    "enableCodeHighlight": true,
    "codeHighlightLanguages": ["javascript", "tsx"]
  }
}
```

Note the key renames: the plugin's `codeHighlight.enabled` / `codeHighlight.languages` become
`enableCodeHighlight` / `codeHighlightLanguages`. Then run `pod install` (iOS) or rebuild (Android).
These are compile/link-time settings, so they apply only in builds you compile yourself (a custom dev
client or `expo prebuild`) — they cannot be changed in Expo Go, which ships a fixed prebuilt binary.

The `@expo/config-plugins` peer dependency was dropped as part of this removal.

### Feature config moved to `package.json`; ENV vars and gradle properties are deprecated

The `enriched-markdown` block in your app's `package.json` is now the single source of truth for
`enableMath`, `enableCodeHighlight`, and `codeHighlightLanguages` on both platforms — the native build
reads it directly at `pod install` / Gradle configuration time. The previous build flags still work as a
fallback but are deprecated, print a warning, and are ignored when the matching `package.json` key is set:

| Deprecated flag                                                                                                | Replaced by (`package.json` `enriched-markdown`) |
| -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| Podfile `ENV['ENRICHED_MARKDOWN_ENABLE_MATH']` / gradle `enrichedMarkdown.enableMath`                          | `enableMath`                                     |
| Podfile `ENV['ENRICHED_MARKDOWN_ENABLE_CODE_HIGHLIGHT']` / gradle `enrichedMarkdown.enableCodeHighlight`       | `enableCodeHighlight`                            |
| Podfile `ENV['ENRICHED_MARKDOWN_CODE_HIGHLIGHT_LANGUAGES']` / gradle `enrichedMarkdown.codeHighlightLanguages` | `codeHighlightLanguages`                         |

In a monorepo the _build_ flag is read from the app's `package.json` (the one beside `ios/`/`android/`),
so each app configures independently. The _download_ opt-out is read where the install runs — usually the
workspace root — so put it in the root `package.json` to skip a download for the whole repo. See
[Native assets](./NATIVE_ASSETS.md).

> [!CAUTION]
> In 1.0.2 through 1.1.1 the download opt-out is read from the workspace root **only**: a block in a
> workspace app's `package.json` disables the feature at build time but does not stop the install-time
> download. Later releases also read the workspace members that depend on the package, so an app-level
> block is enough when every consuming app opts out. See
> [Which `package.json`?](./NATIVE_ASSETS.md#skipping-the-download-opt-out).

### Explicitly enabling a feature whose assets are missing now fails the build

Previously, a missing native asset (the [RaTeX](https://ratex.lites.dev/) XCFramework, or the tree-sitter grammars) always silently
disabled the feature. Now, if you **explicitly** set `enableMath: true` (iOS) or `enableCodeHighlight: true` (iOS and Android) but
the asset was not downloaded (for example an install with `--ignore-scripts`, or a monorepo root opt-out
that an app overrides), the build fails with an actionable error instead of degrading. Features left on by
default still degrade to a clean build. To fix, restore the assets:

```sh
node node_modules/react-native-enriched-markdown/postinstall.mjs
# or: npm rebuild react-native-enriched-markdown
```

then re-run `pod install` (iOS) / rebuild (Android).
