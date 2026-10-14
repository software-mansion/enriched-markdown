---
sidebar_label: Breaking changes
sidebar_position: 2
---

# Breaking changes

:::tip
Looking for the full release notes? See the [changelog](https://swmansion.com/changelog/react-native-enriched-markdown/). This page covers only breaking changes and how to migrate.
:::

This page tracks breaking changes and how to migrate for each, newest first, for the React Native package and the standalone [Android](#android-package) and [iOS](#ios-package) packages. Each package is versioned on its own. Deprecations (things that still work but are slated for removal) are noted alongside the change that introduces them.

The React Native sections come first. Its current release is **1.1.1**, a patch over 1.1.0; neither introduced breaking changes.

## v1.0.2

### The Expo config plugin was removed

The built-in Expo config plugin (`app.plugin.js` and the `plugin/` folder) has been removed. Feature configuration now lives entirely in your app's `package.json`, read directly by the native build and by `postinstall` - the same approach `react-native-worklets` uses for its static feature flags.

Why: the plugin only wrote the (now deprecated) Podfile `ENV` / `gradle.properties` channels, it could never influence the install-time asset download (it runs during `expo prebuild`, _after_ `npm install`), and its option shape diverged from the `package.json` block. The `package.json` block supersedes it for both the download and the build, and it survives `expo prebuild`.

**Migrate:** remove the plugin entry from `app.json` / `app.config.js` and move the options into the `enriched-markdown` block of your `package.json`.

Before (`app.json`):

```json
{
  "expo": {
    "plugins": [
      [
        "react-native-enriched-markdown",
        {
          "enableMath": false,
          "codeHighlight": { "enabled": true, "languages": ["javascript", "tsx"] }
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

Note the key renames: the plugin's `codeHighlight.enabled` / `codeHighlight.languages` become `enableCodeHighlight` / `codeHighlightLanguages`. Then run `pod install` (iOS) or rebuild (Android). These are compile/link-time settings, so they apply only in builds you compile yourself (a custom dev client or `expo prebuild`) - they cannot be changed in Expo Go. The `@expo/config-plugins` peer dependency was dropped as part of this removal.

### Feature config moved to `package.json`; ENV vars and gradle properties are deprecated

The `enriched-markdown` block in your app's `package.json` is now the single source of truth for the compile-time feature flags - `enableMath`, `enableCodeHighlight`, `codeHighlightLanguages`, and since 1.1.0 `enableVideo` as well - on both platforms - the native build reads it directly at `pod install` / Gradle configuration time. The previous build flags still work as a fallback but are deprecated, print a warning, and are ignored when the matching `package.json` key is set:

| Deprecated flag | Replaced by (`enriched-markdown` in `package.json`) |
|---|---|
| `ENV['ENRICHED_MARKDOWN_ENABLE_MATH']` / `enrichedMarkdown.enableMath` | `enableMath` |
| `ENV['ENRICHED_MARKDOWN_ENABLE_CODE_HIGHLIGHT']` / `enrichedMarkdown.enableCodeHighlight` | `enableCodeHighlight` |
| `ENV['ENRICHED_MARKDOWN_CODE_HIGHLIGHT_LANGUAGES']` / `enrichedMarkdown.codeHighlightLanguages` | `codeHighlightLanguages` |

In a monorepo the _build_ flag is read from the app's `package.json` (beside `ios/` / `android/`), so each app configures independently; the _download_ opt-out is read where the install runs (usually the workspace root). See [Native assets](/react-native/guides/native-assets#reducing-binary-size).

:::caution
In 1.0.2 through 1.1.1 the download opt-out is read from the workspace root **only**: a block in a workspace app's `package.json` disables the feature at build time but does not stop the install-time download. Later releases also read the workspace members that depend on the package, so an app-level block is enough when every consuming app opts out. See [Native assets](/react-native/guides/native-assets#reducing-binary-size).
:::

### Explicitly enabling a feature whose assets are missing now fails the build

Previously, a missing native asset (the [RaTeX](https://ratex.lites.dev/) XCFramework, or the tree-sitter grammars) always silently disabled the feature. Now, if you **explicitly** set `enableMath: true` or `enableCodeHighlight: true` but the asset was not downloaded (for example an install with `--ignore-scripts`, or a monorepo root opt-out that an app overrides), the build fails with an actionable error instead of degrading. Features left on by default still degrade to a clean build. To fix, restore the assets:

```sh
node node_modules/react-native-enriched-markdown/postinstall.mjs
# or: npm rebuild react-native-enriched-markdown
```

then re-run `pod install` (iOS) / rebuild (Android).

## Android package {#android-package}

### 0.2.0 to 0.3.0

#### `MarkdownTheme` now requires a style

`MarkdownTheme(style, content)` no longer defaults `style` to the enclosing
theme (#948), so `MarkdownTheme { ... }` with no argument stops compiling.
Pass the style you want the subtree to use. `EnrichedMarkdownText` with no
theme around it still renders with `MarkdownStyle.Default`, so a
`MarkdownTheme` that only wrapped content to get the defaults can be removed.

Before:

```kotlin
MarkdownTheme {
  EnrichedMarkdownText(markdown = text)
}
```

After:

```kotlin
MarkdownTheme(style = appMarkdownStyle) {
  EnrichedMarkdownText(markdown = text)
}
```

#### Style DSL scope types moved package

The builder scopes (`TextStyleScope`, `LinkStyleScope`, `CodeBlockStyleScope`,
`TableStyleScope` and the rest, plus the `ParagraphStyleScope` /
`HeadingStyleScope` aliases) moved from `com.swmansion.enriched.markdown.compose`
to `com.swmansion.enriched.markdown.compose.patches` (#900). Code that only
writes `markdownStyle { paragraph { ... } }` is unaffected; code that names a
scope type, for example in an extension function, needs its import updated.

#### `ui` module rendering internals

`Renderer.getCollectedImageSpans()` and `RenderedSegment.Text.imageSpans` were
removed from the `ui` module (#926); spans that need the hosting `TextView` now
register through `TextViewAwareSpan`. These are rendering internals that
`compose` re-exports only transitively - apps that use `EnrichedMarkdownText`
are unaffected.

### 0.1.0 to 0.2.0

0.2.0 aligned the Compose API with Compose naming conventions (#872). These are
hard renames with no deprecated aliases, so each is a compile error until
migrated:

| 0.1.0 | 0.2.0 |
|---|---|
| `onLinkPress: ((String) -> Unit)?` | `onLinkClick: (String) -> Unit` (defaults to `{}`, no longer nullable) |
| `onLinkLongPress: ((String) -> Unit)?` | `onLinkLongClick: (String) -> Unit` |
| `MarkdownStyle.copy { ... }` | `MarkdownStyle.merge { ... }` (also `merge(other)` and `+`) |
| `link { underline = true }` | `link { textDecoration = TextDecoration.Underline }` |
| `textAlign = TextAlignment.X` (library enum) | `textAlign = TextAlign.X` (Compose's `TextAlign`) |
| `list { marginLeft = ... }` | `list { marginStart = ... }` |
| `image { borderRadius = ... }` | `image { cornerRadius = ... }` |
| `Md4cFlags.DEFAULT` | `Md4cFlags.Default` |

The style scopes also gained `internal` constructors, so they can only be
reached through the `markdownStyle { }` builder. Task lists, tables and the
`flags` parameter first shipped in 0.2.0, so their names
(`onTaskListItemToggle`, `taskListToggleEnabled`, `table { alignment = ... }`)
have nothing to migrate from in a 0.1.0 app.

## iOS package {#ios-package}

### 0.1 to 0.4.0

0.4.0 aligned the public API with SwiftUI conventions. Every 0.1 name still
compiles as a deprecated alias that forwards to its replacement (most with an
Xcode fix-it); they will be removed in the next major version.

| 0.1 | 0.4.0 |
|---|---|
| `Md4cFlags`, `EnrichedMarkdownText(_:flags:)`, `MarkdownRenderer.render(_:config:flags:)`, `Parser.parseMarkdown(_:flags:)` | `MarkdownParsingOptions`, `options:` |
| `.onLinkPress { url in ... }` | `.environment(\.openURL, OpenURLAction { url in ...; return .handled })` |
| `.onLinkLongPress` | `.onMarkdownLinkLongPress` |
| `.onTaskListItemPress`, `TaskListItemPressEvent(index:checked:text:)`, `.checked` | `.onTaskListItemToggle`, `TaskListItemToggle(index:isChecked:text:)`, `.isChecked` |
| `.markdownSelectable(false)` | `.markdownTextSelection(.disabled)` |
| `MarkdownSelectionMenuConfig(copyImageUrl:)` | `MarkdownSelectionMenu(copyImageURL:)` |
| `rememberMarkdownTheme(colorScheme:dynamicTypeSize:) { ... }` | `MarkdownTheme { ... }` built in `body` (the old parameters were ignored) |
| `.textAlignment(_:)` | `.multilineTextAlignment(_:)` |
| `.borderRadius(_:)` on `BlockImage`, `CodeBlock`, `Table` | `.cornerRadius(_:)` |
| `TaskList().checkboxBorderRadius(_:)` | `.checkboxCornerRadius(_:)` |
| `List().marginLeft(_:)` | `.marginLeading(_:)` |
| `Table().align(_: TableAlignment)` | `.alignment(_: HorizontalAlignment)` |
| `ThematicBreak().color(_:)`, `Spoiler().color(_:)` | `.foregroundStyle(_:)` |
| `.borderColor(_:)` + `.borderWidth(_:)` on `CodeBlock`, `Blockquote`, `Table` | `.border(_:width:)` |
| `Table().cellPaddingHorizontal(_:)` / `.cellPaddingVertical(_:)` | `.cellPadding(horizontal:vertical:)` |
| `Spoiler().particleDensity(_:)` / `.particleSpeed(_:)` / `.solidBorderRadius(_:)` | `.markdownSpoilerOverlay(.particles(density:speed:))` / `.markdownSpoilerOverlay(.solid(cornerRadius:))` |
| `.fontSize(_:weight:)`, `.fontFamily(_:size:)` | `.font(size:weight:design:)`, `.font(custom:size:)` |
| `Table().headerFontFamily(_:size:)`, `.headerTextColor(_:)` | `.headerFont(custom:size:)`, `.headerForegroundStyle(_:)` |
| `MarkdownStyleConfig` | `MarkdownStyleConfiguration` (the `config:` label is unchanged) |
| `CodeBlockStyle.borderRadius`, `ImageStyle.borderRadius`, `TableStyle.borderRadius` / `.align`, `TaskListStyle.checkboxBorderRadius`, `ListStyle.marginLeft`, `SpoilerStyle.solidBorderRadius` | `cornerRadius`, `alignment`, `checkboxCornerRadius`, `marginLeading`, `solidCornerRadius` (fields and init labels) |

Two changes have no alias:

- **The last block's bottom margin is dropped by default.** 0.1 always laid it
  out below the text; the view now ends at its last line. Add
  `.markdownBottomMargin(.visible)` to bring it back.
- **The `EnrichedMarkdown` namespace enum was removed.** It shadowed the
  module name, so `EnrichedMarkdown.List()` now resolves as a module-qualified
  lookup.
