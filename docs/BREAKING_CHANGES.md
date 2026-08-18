# Breaking changes

This file tracks breaking changes and how to migrate for each. Entries are newest first. Deprecations
(things that still work but are slated for removal) are noted alongside the change that introduces them.

## Unreleased

### The Expo config plugin was removed

The built-in Expo config plugin (`app.plugin.js` and the `plugin/` folder) has been removed. Feature
configuration now lives entirely in your app's `package.json`, read directly by the native build and by
`postinstall` — the same approach `react-native-worklets` uses for its static feature flags.

Why: the plugin only wrote the (now deprecated) Podfile `ENV` / `gradle.properties` channels, it could
never influence the install-time asset download (it runs during `expo prebuild`, *after* `npm install`),
and its option shape diverged from the `package.json` block. The `package.json` block supersedes it for
both the download and the build, and it survives `expo prebuild`.

**Migrate:** remove the plugin entry from `app.json` / `app.config.js` and move the options into the
`enriched-markdown` block of your `package.json`.

Before (`app.json`):

```json
{
  "expo": {
    "plugins": [
      ["react-native-enriched-markdown", {
        "enableMath": false,
        "codeHighlight": { "enabled": true, "languages": ["javascript", "tsx"] }
      }]
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

| Deprecated flag | Replaced by (`package.json` `enriched-markdown`) |
|---|---|
| Podfile `ENV['ENRICHED_MARKDOWN_ENABLE_MATH']` / gradle `enrichedMarkdown.enableMath` | `enableMath` |
| Podfile `ENV['ENRICHED_MARKDOWN_ENABLE_CODE_HIGHLIGHT']` / gradle `enrichedMarkdown.enableCodeHighlight` | `enableCodeHighlight` |
| Podfile `ENV['ENRICHED_MARKDOWN_CODE_HIGHLIGHT_LANGUAGES']` / gradle `enrichedMarkdown.codeHighlightLanguages` | `codeHighlightLanguages` |

In a monorepo the *build* flag is read from the app's `package.json` (the one beside `ios/`/`android/`),
so each app configures independently. The *download* opt-out is read where the install runs — usually the
workspace root — so put it in the root `package.json` to skip a download for the whole repo. See
[Native assets](./NATIVE_ASSETS.md).

### Explicitly enabling a feature whose assets are missing now fails the build

Previously, a missing native asset (the RaTeX XCFramework, or the tree-sitter grammars) always silently
disabled the feature. Now, if you **explicitly** set `enableMath: true` or `enableCodeHighlight: true` but
the asset was not downloaded (for example an install with `--ignore-scripts`, or a monorepo root opt-out
that an app overrides), the build fails with an actionable error instead of degrading. Features left on by
default still degrade to a clean build. To fix, restore the assets:

```sh
node node_modules/react-native-enriched-markdown/postinstall.mjs
# or: npm rebuild react-native-enriched-markdown
```

then re-run `pod install` (iOS) / rebuild (Android).
