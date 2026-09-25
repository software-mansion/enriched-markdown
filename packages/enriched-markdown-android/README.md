<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/user-attachments/assets/502ff54f-93c9-4ce5-801d-df079174ea92">
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/user-attachments/assets/0f9fc1e6-82f5-4116-8ff6-d19d574e3760">
  <img alt="Enriched Markdown by Software Mansion" src="https://github.com/user-attachments/assets/502ff54f-93c9-4ce5-801d-df079174ea92">
</picture>

# Enriched Markdown Android

Standalone Android library for rendering enriched Markdown in Jetpack Compose. This package is separate from the React Native npm package and is published to Maven Central.

## Installation

```kotlin
repositories {
  google()
  mavenCentral()
}

dependencies {
  implementation("com.swmansion.enriched.markdown:compose:0.2.0")
}
```

Requirements: `minSdk 24`, AndroidX.

The `compose` artifact pulls in internal `ui` and `parser` modules transitively. Consumers should depend only on `compose`.

### Optional plugins

Features with a heavy dependency of their own ship as separate artifacts, installed at runtime. Today there is one: **math**.

```kotlin
dependencies {
  implementation("com.swmansion.enriched.markdown:compose:0.1.0")
  implementation("com.swmansion.enriched.markdown:math:0.1.0") // only if you render LaTeX
}
```

An app that renders no math does not add this line and pays nothing for it — not the artifact, and not its native LaTeX engine. That matters beyond download size: the engine behind `:math` ships no 32-bit `x86` native library (`arm64-v8a`, `armeabi-v7a` and `x86_64` only), so depending on it would otherwise constrain where the whole library can run.

Install the plugin once, at startup, before any markdown is rendered:

```kotlin
import android.app.Application
import com.swmansion.enriched.markdown.math.LatexMathPlugin
import com.swmansion.enriched.markdown.plugin.EnrichedMarkdownPlugins
import com.swmansion.enriched.markdown.plugin.InternalPluginApi

@OptIn(InternalPluginApi::class)
class MyApplication : Application() {
  override fun onCreate() {
    super.onCreate()
    EnrichedMarkdownPlugins.install(LatexMathPlugin)
  }
}
```

…registered in `AndroidManifest.xml`:

```xml
<application android:name=".MyApplication" …>
```

The registry is an internal extension surface — we write and version the plugins alongside core — so installing one needs `@OptIn(InternalPluginApi::class)`. Everything else in this README is ordinary public API.

Without the install call nothing breaks: `$...$` and `$$...$$` render as their raw source, delimiters included, and logcat carries a single `EnrichedMarkdown` warning naming the missing artifact and this call.

The plugin and the parser flag are two separate switches. `Md4cFlags(latexMath = true)` is what makes the parser recognise math at all; the plugin is what draws it. With the flag off, `$...$` is just text, installed plugin or not.

## Quick start

Wrap your app (or a screen) in `MarkdownTheme`, then render markdown with `EnrichedMarkdownText`:

```kotlin
import androidx.compose.material3.MaterialTheme
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.compose.MarkdownTheme

MaterialTheme {
  MarkdownTheme {
    EnrichedMarkdownText(
      markdown = "# Hello\n\nThis is **enriched** markdown.",
      onLinkClick = { url -> /* open url */ },
    )
  }
}
```

See the full example in [`apps/android-example`](../../apps/android-example).

## Styling

Build styles with `markdownStyle { }` and pass them to `MarkdownTheme` or per-component via the `style` parameter:

```kotlin
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swmansion.enriched.markdown.compose.MarkdownStyle
import com.swmansion.enriched.markdown.compose.markdownStyle

val AppMarkdownStyle: MarkdownStyle = markdownStyle {
  paragraph {
    fontSize = 16.sp
    color = Color(0xFF1F2937)
    lineHeight = 26.sp
    marginBottom = 16.dp
  }
  h1 {
    fontSize = 30.sp
    color = Color(0xFF111827)
  }
  link {
    color = Color(0xFF2563EB)
    textDecoration = TextDecoration.Underline
  }
  codeBlock {
    fontSize = 14.sp
    color = Color(0xFFF3F4F6)
    backgroundColor = Color(0xFF1F2937)
    cornerRadius = 8.dp
    padding = 16.dp
  }
}

// App-wide default
MarkdownTheme(style = AppMarkdownStyle) {
  HomeScreen()
}

// Per-instance override
EnrichedMarkdownText(
  markdown = content,
  style = AppMarkdownStyle.merge {
    link { color = Color.Red }
  },
)
```

When styles reference `MaterialTheme` tokens, use `rememberMarkdownStyle` so they update with theme changes:

```kotlin
MarkdownTheme(
  style = rememberMarkdownStyle {
    paragraph { color = MaterialTheme.colorScheme.onSurface }
    link { color = MaterialTheme.colorScheme.primary }
  },
) {
  Content()
}
```

### Style blocks

The `markdownStyle` builder supports these blocks:

| Block | Applies to |
|-------|------------|
| `paragraph` | Body text |
| `h1` … `h6` | Headings |
| `link` | Links |
| `strong` | Bold text |
| `emphasis` | Italic text |
| `strikethrough` | Struck-through text |
| `underline` | Underlined text (requires `Md4cFlags(underline = true)`) |
| `superscript` | Superscript text (`^text^`) |
| `subscript` | Subscript text (`~text~`) |
| `code` | Inline code |
| `codeBlock` | Fenced code blocks |
| `blockquote` | Block quotes, and `admonitions { }` for GitHub alerts (requires `Md4cFlags(admonitions = true)`) |
| `list` | Ordered and unordered lists |
| `taskList` | Task list checkboxes |
| `image` | Block images |
| `inlineImage` | Inline images |
| `thematicBreak` | Horizontal rules |
| `table` | Tables |
| `spoiler` | The overlay that conceals `\|\|spoiler\|\|` text |
| `math` | Block LaTeX math (`$$...$$`; needs the `:math` artifact and `Md4cFlags(latexMath = true)`) |
| `inlineMath` | Inline LaTeX math (`$...$`; same two requirements) |

Use `MarkdownStyle.merge { }` to layer overrides (e.g. light/dark variants) without rebuilding the full style. `a.merge(b)` and `a + b` layer a whole style on top of another the same way.

`superscript` and `subscript` take unitless floats instead of `Dp`/`sp`/`Color`: `fontScale` shrinks the text size relative to its surrounding text, and `baselineOffsetScale` shifts the baseline (as a fraction of text size) up for superscript and down for subscript.

```kotlin
markdownStyle {
  superscript {
    fontScale = 0.65f
    baselineOffsetScale = 0.35f
  }
  subscript {
    fontScale = 0.65f
    baselineOffsetScale = 0.2f
  }
}
```

Rendering `^text^`/`~text~` as superscript/subscript nodes requires enabling the corresponding `Md4cFlags` when parsing.

`spoiler` styles the overlay that conceals `||spoiler||` text. `color` paints the particles and fills
the solid block; `particles { density, speed }` only apply to `SpoilerOverlay.Particles` and are
unitless multipliers over the defaults shown below, and `solid { cornerRadius }` only applies to
`SpoilerOverlay.Solid`. The concealed text itself is drawn transparent, so the overlay works over any
background without being told what that background is.

```kotlin
markdownStyle {
  spoiler {
    color = Color(0xFF374151)
    particles {
      density = 8f
      speed = 20f
    }
    solid { cornerRadius = 4.dp }
  }
}
```

### Math style blocks

`math` and `inlineMath` come from the `:math` artifact, not from the builder itself: they are extension functions on `MarkdownStyleBuilder`, so they need an import before they resolve.

```kotlin
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swmansion.enriched.markdown.compose.markdownStyle
import com.swmansion.enriched.markdown.math.compose.inlineMath
import com.swmansion.enriched.markdown.math.compose.math
import com.swmansion.enriched.markdown.styles.TextAlignment

markdownStyle {
  math {
    fontSize = 20.sp
    color = Color(0xFF1F2937)
    backgroundColor = Color(0xFFF3F4F6)
    padding = 12.dp
    marginTop = 0.dp
    marginBottom = 16.dp
    textAlign = TextAlignment.CENTER
  }
  inlineMath {
    color = Color(0xFF7C3AED)
  }
}
```

`math` styles standalone equations: `fontSize`, `color`, `backgroundColor`, `padding`, `marginTop`, `marginBottom`, and `textAlign` (`LEFT`, `CENTER` — the default — or `RIGHT`). `inlineMath` takes a `color` only; its size follows the surrounding text.

Properties you leave unset keep the plugin's own defaults, which live in `:math` rather than in core. Repeating either block merges into the earlier one, exactly like the built-in blocks, so `MarkdownStyle.merge { math { … } }` layers over a base style.

## API reference

### `EnrichedMarkdownText`

```kotlin
@Composable
fun EnrichedMarkdownText(
  markdown: String,
  modifier: Modifier = Modifier,
  style: MarkdownStyle = MarkdownTheme.style,
  flags: Md4cFlags = Md4cFlags.Default,
  selectable: Boolean = true,
  imageRequestHeaders: Map<String, String> = emptyMap(),
  onLinkClick: (String) -> Unit = {},
  onLinkLongClick: (String) -> Unit = {},
  onTaskListItemToggle: (TaskListItemToggle) -> Unit = {},
  taskListToggleEnabled: Boolean = true,
  spoilerOverlay: SpoilerOverlay = SpoilerOverlay.Particles,
  onPluginEvent: (PluginEvent) -> Unit = {},
)
```

| Parameter | Description |
|-----------|-------------|
| `markdown` | Markdown source string |
| `style` | Per-instance style override |
| `flags` | Optional parser extensions (see `Md4cFlags`) |
| `selectable` | Enable text selection |
| `imageRequestHeaders` | HTTP headers attached to remote image requests (e.g. `Referer`) |
| `onLinkClick` | Called when a link is tapped |
| `onLinkLongClick` | Called when a link is long-pressed |
| `onTaskListItemToggle` | Called after a task list checkbox tap toggles the item |
| `taskListToggleEnabled` | Whether a checkbox tap toggles the item (default `true`) |
| `spoilerOverlay` | How `\|\|spoiler\|\|` text is concealed: `SpoilerOverlay.Particles` (default) or `SpoilerOverlay.Solid` |
| `onPluginEvent` | Called when an installed plugin reports a problem, e.g. a LaTeX expression it could not draw (see below) |

Style defaults come from the nearest `MarkdownTheme`.

> **Note:** Renders nothing in `@Preview` because it relies on `AndroidView`.

#### Task list checkboxes

```kotlin
data class TaskListItemToggle(
  val index: Int,     // 0-based, in document order
  val checked: Boolean, // state after the toggle
  val text: String,   // first line of the item's plain text
)
```

Tapping anywhere in a task item's checkbox margin toggles its checked state in
place — checkbox and checked-item text decoration alike — and calls
`onTaskListItemToggle` with the new state. The toggle is visual: the view never
rewrites the `markdown` string you pass it, so persist the change from the
handler if it has to survive a new source string. Re-supplying the *same*
string on recomposition keeps the toggles.

```kotlin
EnrichedMarkdownText(
  markdown = checklist,
  onTaskListItemToggle = { (index, checked, _) -> store.setDone(index, checked) },
)
```

`taskListToggleEnabled = false` makes checkbox taps fully inert: no visual
toggle and no `onTaskListItemToggle`. Text selection and links are unaffected
either way.

#### LaTeX math

With the `:math` artifact on the classpath, `EnrichedMarkdownPlugins.install(LatexMathPlugin)`
called at startup, and `Md4cFlags(latexMath = true)` on the instance, `$...$` renders inline
within the text and `$$...$$` on its own line renders as a standalone, horizontally scrollable
block. Long-press a block equation to copy its LaTeX source or copy it as Markdown. Display math
that appears mid-line (`a $$x$$ b`) stays in the text flow rather than breaking the paragraph.

```kotlin
EnrichedMarkdownText(
  markdown = "Mass-energy: \$E = mc^2\$\n\n\$\$\n\\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}\n\$\$",
  flags = Md4cFlags(latexMath = true),
)
```

Miss any of the three and the math still reaches the screen, unrendered: with the flag off it is
literal text, and with the flag on but no plugin installed it is its own raw source, delimiters
included, plus one warning in logcat.

#### `onPluginEvent` and `LatexErrorEvent`

Installed plugins report per-view problems through `onPluginEvent`, a single channel shared by
every plugin rather than one callback per feature. The math plugin sends a `LatexErrorEvent` when
the engine cannot draw an expression (an unsupported command, a syntax error); the expression then
shows as its raw source.

```kotlin
import com.swmansion.enriched.markdown.math.LatexErrorEvent

EnrichedMarkdownText(
  markdown = content,
  flags = Md4cFlags(latexMath = true),
  onPluginEvent = { event ->
    if (event is LatexErrorEvent) {
      Log.w("Latex", "${event.source} failed: ${event.message}")
    }
  },
)
```

```kotlin
data class LatexErrorEvent(
  val source: String,       // the whole failing expression, without $ / $$ delimiters
  val message: String?,     // the engine's error, when it gave one
  val displayMode: Boolean, // false for inline $...$, true for block $$...$$
  val pluginId: String,     // LatexMathPlugin.ID
) : PluginEvent
```

Each view reports a distinct event at most once, by event equality, and keeps remembering it when
`markdown` changes, so streamed content does not report the same failure on every update. A
recycled view starts with an empty record. `PluginEvent` itself carries only `pluginId`, so check
the type — as above — before reading a plugin's own fields.

### `Md4cFlags`

```kotlin
data class Md4cFlags(
  val underline: Boolean = false,    // _text_ and __text__ render underlined instead of italic and bold
  val superscript: Boolean = false,  // ^text^ renders raised above the baseline
  val subscript: Boolean = false,    // ~text~ renders lowered below the baseline
  val latexMath: Boolean = false,    // $...$ and $$...$$ parse as math nodes
  val admonitions: Boolean = false,  // `> [!NOTE]` blockquotes render as GitHub alerts
  // … further md4c extensions
) {
  companion object {
    val Default: Md4cFlags
  }
}
```


Pass flags per instance:

```kotlin
import com.swmansion.enriched.markdown.compose.Md4cFlags

EnrichedMarkdownText(
  markdown = "_underlined_",
  flags = Md4cFlags(underline = true),
)
```

### `MarkdownTheme`

```kotlin
@Composable
fun MarkdownTheme(
  style: MarkdownStyle = LocalMarkdownStyle.current,
  content: @Composable () -> Unit,
)

object MarkdownTheme {
  val style: MarkdownStyle  // current theme style
}
```

Provides a default `MarkdownStyle` for a subtree. Nest themes to scope styles to part of the UI.

### `markdownStyle` / `MarkdownStyle`

```kotlin
fun markdownStyle(block: MarkdownStyleBuilder.() -> Unit): MarkdownStyle

class MarkdownStyle {
  fun merge(block: MarkdownStyleBuilder.() -> Unit): MarkdownStyle
  fun merge(other: MarkdownStyle): MarkdownStyle
  operator fun plus(other: MarkdownStyle): MarkdownStyle
  companion object {
    val Default: MarkdownStyle
  }
}
```

### `rememberMarkdownStyle`

```kotlin
@Composable
fun rememberMarkdownStyle(
  vararg keys: Any?,
  block: MarkdownStyleBuilder.() -> Unit,
): MarkdownStyle
```

Creates a style that tracks `MaterialTheme.colorScheme` changes. Use inside `MaterialTheme { }`.

`TextAlign.Unspecified` keeps the inherited alignment.

Style scope constructors are `internal` — build scopes through the `markdownStyle { }` DSL, which is
the only supported way to reach them.

## Supported Markdown

- Headings (`#`–`######`)
- Paragraphs, line breaks
- **Bold**, *italic*, `inline code`, __underline__, ~~strikethrough~~, ^superscript^, ~subscript~
- Fenced code blocks
- Block quotes
- Ordered and unordered lists
- Task lists (`- [ ]` / `- [x]`, tap to toggle — see `onTaskListItemToggle`)
- Links and images (block and inline)
- Thematic breaks (`---`)
- Spoilers (`||hidden||`, tap to reveal). Adjacent spoilers reveal together. Concealment is visual
  only: screen readers read concealed text as ordinary text, and a plain Copy yields it too (Copy as
  Markdown keeps the `||` markers)
- Admonitions / GitHub alerts (`> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`) — requires `Md4cFlags(admonitions = true)`
- Tables (GFM), including per-column alignment
- LaTeX math, inline (`$...$`) and block (`$$...$$`) — requires `Md4cFlags(latexMath = true)` and the `:math` artifact

### Admonitions

A blockquote whose first line is one of the five GitHub alert markers renders as a themed callout —
the usual blockquote geometry plus a header row with a tinted octicon and a bold title:

```markdown
> [!WARNING]
> This action cannot be undone.
```

Admonitions are an opt-in parser extension, so pass the flag to enable them; without it the marker
stays literal text inside an ordinary quote:

```kotlin
EnrichedMarkdownText(
  markdown = content,
  flags = Md4cFlags(admonitions = true),
)
```

Each type has a `color` (which tints the accent bar, the title and the icon) and an optional
`backgroundColor`. The defaults are the GitHub palette; backgrounds are unset, so a callout is drawn
unfilled unless you opt in:

```kotlin
markdownStyle {
  blockquote {
    admonitions {
      warning {
        color = Color(0xFF9A6700)
        backgroundColor = Color(0xFFFFF8C5)
      }
      caution { color = Color(0xFFCF222E) }
    }
  }
}
```

Types you do not name keep their defaults, and the surrounding `blockquote { }` properties
(`fontSize`, `lineHeight`, `padding`, …) still apply to the callout's body. The title is always
bold, whatever `fontWeight` the blockquote style carries.

Copying a callout reproduces its `> [!NOTE]` marker, and screen readers announce the header as an
"alert" node ahead of the body.

An admonition nested inside a list item falls back to a plain blockquote with no header. This
matches the React Native renderers on both platforms, so the same document looks the same
everywhere.

### Tables

A table is rendered as its own scrollable child view rather than as text, so it can be styled
independently of the surrounding body text:

```kotlin
markdownStyle {
  table {
    fontSize = 14.sp
    color = Color(0xFF1F2937)
    headerBackgroundColor = Color(0xFFF3F4F6)
    headerTextColor = Color(0xFF111827)
    rowEvenBackgroundColor = Color.White
    rowOddBackgroundColor = Color(0xFFF9FAFB)
    borderColor = Color(0xFFE5E7EB)
    borderWidth = 1.dp
    cornerRadius = 6.dp
    cellPaddingHorizontal = 12.dp
    cellPaddingVertical = 8.dp
    alignment = Alignment.CenterHorizontally
  }
}
```

A column is sized to its widest cell, within 60dp-300dp. A table wider than the space available keeps
those widths and scrolls sideways, with a horizontal scrollbar. `alignment` places a table that is
narrower than the available width; it defaults to `Alignment.Start`. `Alignment.Start` / `.End`
follow the reading direction, while `AbsoluteAlignment.Left` / `.Right` pin a side regardless of it.
`horizontalOverflow` lets a table bleed that far past the container's content box on each side, so it
can reach the screen edge while the body text stays inset.

Long-pressing a table offers **Copy** (rich text) and **Copy as Markdown**.


## Development

```sh
yarn workspace @enriched-markdown/android build
yarn workspace @enriched-markdown/android test:android-native
yarn workspace @enriched-markdown/android lint:android-native
```

## Publishing

Version is defined in `gradle.properties` as `VERSION_NAME`.

```sh
# Local dry run (no signing required)
yarn workspace @enriched-markdown/android publish:maven-local

# Maven Central (requires MAVEN_USERNAME, MAVEN_PASSWORD, GPG_PRIVATE_KEY, GPG_PASSPHRASE)
yarn workspace @enriched-markdown/android publish:maven-central
```

Published artifacts land under `~/.m2/repository/com/swmansion/enriched/markdown/` after a local publish.
