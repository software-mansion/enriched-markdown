---
sidebar_label: EnrichedMarkdownText
sidebar_position: 1
---

# EnrichedMarkdownText

`EnrichedMarkdownText` renders Markdown as fully native text. It parses with [md4c](https://github.com/mity/md4c) and paints the result with Android's own text stack, so selection, TalkBack, and font scaling all behave like first-class native text.

```kotlin
@Composable
fun EnrichedMarkdownText(
  markdown: String,
  modifier: Modifier = Modifier,
  style: MarkdownStyle = MarkdownTheme.style,
  options: MarkdownOptions = MarkdownOptions.Default,
  selectable: Boolean = true,
  codeBlockLayout: CodeBlockLayout = CodeBlockLayout.Wrapping,
  imageRequestHeaders: Map<String, String> = emptyMap(),
  onLinkClick: (String) -> Unit = {},
  onLinkLongClick: (String) -> Unit = {},
  onTaskListItemToggle: (TaskListItemToggle) -> Unit = {},
  onCodeBlockCopy: (CodeBlockCopy) -> Unit = {},
  taskListToggleEnabled: Boolean = true,
  spoilerOverlay: SpoilerOverlay = SpoilerOverlay.Particles(),
  includeLastBlockMargin: Boolean = false,
  plugins: List<MarkdownPlugin> = LocalMarkdownPlugins.current,
  onPluginEvent: (PluginEvent) -> Unit = {},
)
```

`EnrichedMarkdownText`, `MarkdownStyle`, `MarkdownTheme`, `MarkdownOptions`, `CodeBlockLayout`, `CodeBlockCopy`, `TaskListItemToggle`, `MarkdownPlugin`, `LocalMarkdownPlugins`, and `PluginEvent` all import from `com.swmansion.enriched.markdown.compose`. `SpoilerOverlay` imports from `com.swmansion.enriched.markdown.spoiler`.

:::note
The composable wraps a real Android `View` through `AndroidView`, so it renders **nothing** in `@Preview`. Run it on a device or emulator.
:::

## Parameters

### `markdown`

The Markdown source to render. Which syntax is recognized depends on [`options`](#options) - see [Feature support](/introduction/supported-features) for the full matrix and [Element structure](/android/api-reference/element-structure) for what each element renders as.

<PropInfo type="String" required />

```kotlin
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText

EnrichedMarkdownText(markdown = "# Inline\n\nA **bold** word and a [link](https://swmansion.com).")
```

### `modifier`

The Compose [`Modifier`](https://developer.android.com/develop/ui/compose/modifiers) applied to the wrapping `AndroidView`. Use it for layout and decoration around the text - `fillMaxWidth`, `padding`, `background`, and so on. To style the Markdown itself, use [`style`](#style).

<PropInfo type="Modifier" default="Modifier" />

```kotlin
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText

EnrichedMarkdownText(
  markdown = "Padded, full-width text.",
  modifier = Modifier
    .fillMaxWidth()
    .padding(16.dp),
)
```

### `style` {#style}

A per-instance style override. Defaults to the style provided by the nearest [`MarkdownTheme`](/android/api-reference/markdown-theme), so you usually set this only when one component needs to differ from its surroundings. Build one with the `markdownStyle { }` DSL - see [Style properties](/android/api-reference/style-properties).

<PropInfo type="MarkdownStyle" default="MarkdownTheme.style" />

```kotlin
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.compose.MarkdownTheme
import com.swmansion.enriched.markdown.compose.markdownStyle

val CompactStyle = markdownStyle { paragraph { marginBottom = 4.dp } }

@Composable
fun Bubble(message: String) {
  // Everything else on this screen keeps the ambient theme; this one bubble is compact.
  EnrichedMarkdownText(markdown = message, style = CompactStyle)
}

@Composable
fun RedLinks(message: String) {
  // Or derive from whatever the enclosing theme provides:
  EnrichedMarkdownText(
    markdown = message,
    style = MarkdownTheme.style.merge { link { color = Color.Red } },
  )
}
```

### `options` {#options}

Toggles for the optional syntax extensions. Each one opts a piece of extra syntax in or out; pass only the options you want to change and the rest keep their defaults.

<PropInfo type="MarkdownOptions" default="MarkdownOptions.Default" />

```kotlin
data class MarkdownOptions(
  val underline: Boolean = false,
  val superscript: Boolean = false,
  val subscript: Boolean = false,
  val highlight: Boolean = false,
  val permissiveAutolinks: Boolean = true,
  val hardSoftBreaks: Boolean = false,
  val preserveBlankLines: Boolean = false,
  val preserveWindowsPaths: Boolean = false,
  val admonitions: Boolean = false,
) {
  companion object {
    val Default = MarkdownOptions()
  }
}
```

```kotlin
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.compose.MarkdownOptions

EnrichedMarkdownText(
  markdown = "_underlined_\n\n> [!TIP]\n> Admonitions are on.",
  options = MarkdownOptions(underline = true, admonitions = true),
)
```

:::note
`MarkdownOptions.Default` turns **everything off except `permissiveAutolinks`**.
:::

Some syntax is always on and has no option: tables, `~~strikethrough~~`, task lists (`- [ ]` / `- [x]`), and `||spoilers||`. A spoiler renders concealed until the reader taps it - see [`spoilerOverlay`](#spoileroverlay).

LaTeX math has no option either. Enabling [`LatexMathPlugin`](#plugins) from the `math` artifact turns on parsing `$...$` and `$$...$$` along with rendering them, so math is never parsed with nothing to draw it. Without the plugin, the `$` stays literal text. See [LaTeX math](/android/guides/latex-math).

For a walkthrough of what each extension changes, see [Parser extensions](/android/guides/parser-extensions).

#### `underline`

Renders `_text_` and `__text__` as underlined instead of italic and bold. Style it through the [`underline`](/android/api-reference/style-properties#underline) block.

<PropInfo type="Boolean" default="false" />

#### `superscript`

Renders `^text^` raised above the baseline. Style it through [`superscript`](/android/api-reference/style-properties#superscript).

<PropInfo type="Boolean" default="false" />

#### `subscript`

Renders `~text~` lowered below the baseline. Style it through [`subscript`](/android/api-reference/style-properties#subscript).

<PropInfo type="Boolean" default="false" />

#### `highlight`

Renders `==text==` with a highlight band behind the glyphs. Style it through [`highlight`](/android/api-reference/style-properties#highlight).

<PropInfo type="Boolean" default="false" />

With the option off, the `==` markers stay literal text.

#### `permissiveAutolinks`

Links bare URLs. Plain Markdown only autolinks a URL wrapped in angle brackets - `<https://swmansion.com>` - so with this off, a URL pasted on its own stays inert text. With it on, `https://swmansion.com` becomes a link as written.

This is separate from `[text](url)`, which is an ordinary inline link and always works. The option is the one extension that is **on** by default.

<PropInfo type="Boolean" default="true" />

#### `hardSoftBreaks`

Treats a single newline as a hard line break, so lines inside one paragraph keep the breaks you typed instead of reflowing. See [Line breaks](/android/api-reference/element-structure#line-breaks).

<PropInfo type="Boolean" default="false" />

#### `preserveBlankLines`

Keeps consecutive blank lines instead of collapsing them, so vertical whitespace in the source survives into the output.

<PropInfo type="Boolean" default="false" />

#### `preserveWindowsPaths`

When `true`, a backslash that separates a Windows drive path stays in the text instead of acting as an escape, so `C:\Users\me\.config` keeps every separator. CommonMark would render it as `C:\Users\me.config`. Escapes outside such a path, code spans, and link destinations are unchanged.

<PropInfo type="Boolean" default="false" />

#### `admonitions`

Renders a blockquote whose first line is `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, or `> [!CAUTION]` as a themed callout with an icon and a title. Without it the marker stays literal text inside an ordinary quote. Colors come from the [`admonitions`](/android/api-reference/style-properties#admonitions) block.

<PropInfo type="Boolean" default="false" />

### `selectable`

Whether the reader can select and copy text.

<PropInfo type="Boolean" default="true" />

```kotlin
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText

EnrichedMarkdownText(markdown = "Not selectable.", selectable = false)
```

:::note
A document is laid out as a stack of segments: a text view for each run of ordinary blocks, and a separate view for each table, each top-level code block when [`codeBlockLayout`](#codeblocklayout) is `Scrollable`, and, with the [math plugin](#plugins), each display-math block on its own line. A selection can run across headings, quotes, lists, and code blocks inside one text segment, but it **stops at any of those separate views**, and it cannot span two `EnrichedMarkdownText` composables either.

Those blocks are not text-selectable. Long-press one instead to copy it: a table copies as tab-separated plain text plus HTML, a code block as its code, a formula as its LaTeX source.
:::

#### What copying produces {#copying}

The system **Copy** action writes the selection twice: as rendered plain text, and as styled HTML. Rich text targets - Gmail, Docs - pick up the HTML and keep headings, inline styles, lists, quotes, code blocks, links, and images.

The selection menu also carries two items of the library's own, both on by default:

- **Copy as Markdown** puts the selection on the clipboard as Markdown source rather than rendered text.
- **Copy Image URL** appears when the selection contains images with `http(s)` URLs, and copies them one per line.

Neither can be hidden or relabeled from the Compose API yet. See the [roadmap](/misc/roadmap) and [Copy options](/user-experience/copy-options).

### `codeBlockLayout` {#codeblocklayout}

Whether fenced code blocks wrap long lines or scroll them. With `CodeBlockLayout.Wrapping` a long line wraps, and the code is part of the text selection like any other text.

`CodeBlockLayout.Scrollable` keeps lines intact: a code block at the top level of the document scrolls horizontally inside its box instead. Each such block is a view of its own, so a selection stops at it - long-press it to copy its code, or the code as fenced Markdown. A code block inside a list item or a quote wraps either way. See [Code blocks](/android/api-reference/element-structure#code-blocks).

<PropInfo type="CodeBlockLayout" default="CodeBlockLayout.Wrapping" />

```kotlin
import com.swmansion.enriched.markdown.compose.CodeBlockLayout
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText

EnrichedMarkdownText(
  markdown = content,
  codeBlockLayout = CodeBlockLayout.Scrollable,
)
```

### `imageRequestHeaders`

HTTP headers attached to **remote** image requests - an `Authorization` token, a `Referer`, and so on. They apply to every image the document loads.

<PropInfo type="Map<String, String>" default="emptyMap()" />

```kotlin
import androidx.compose.runtime.Composable
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText

@Composable
fun PrivateDoc(content: String, token: String) {
  EnrichedMarkdownText(
    markdown = content,
    imageRequestHeaders = mapOf("Authorization" to "Bearer $token"),
  )
}
```

Headers take part in the cache key, so the same URL fetched with different headers is cached separately - see [Image caching](/android/guides/image-caching).

### `taskListToggleEnabled` {#tasklisttoggleenabled}

Whether tapping a task list checkbox toggles it. With `false`, checkbox taps are fully inert: no visual toggle and no [`onTaskListItemToggle`](#ontasklistitemtoggle). Text selection and links are unaffected either way.

<PropInfo type="Boolean" default="true" />

```kotlin
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText

// A read-only checklist: boxes render checked or not, but do not respond.
EnrichedMarkdownText(
  markdown = "- [x] Ship it\n- [ ] Write the changelog",
  taskListToggleEnabled = false,
)
```

### `spoilerOverlay` {#spoileroverlay}

How unrevealed `||spoiler||` text is concealed until the reader taps it. Pick a built-in or supply your own. Colors come from the theme's [`spoiler`](/android/api-reference/style-properties#spoiler) block.

<PropInfo type="SpoilerOverlay" default="SpoilerOverlay.Particles()" />

```kotlin
sealed interface SpoilerOverlay {
  data class Particles(
    val density: Float = 8f, // how thickly the field is populated; particle count scales linearly
    val speed: Float = 20f,  // how fast particles drift; velocity scales linearly
  ) : SpoilerOverlay

  data class Solid(
    val cornerRadius: Float = 4f, // in dp
  ) : SpoilerOverlay
}

interface CustomSpoilerOverlay : SpoilerOverlay
```

- `Particles` - a field of drifting particles in the spoiler color.
- `Solid` - a solid rounded box in the spoiler color. In Compose you can pass the radius as a `Dp` through the `SpoilerOverlay.Solid(cornerRadius: Dp)` factory, which needs its own import.

```kotlin
import androidx.compose.ui.unit.dp
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.compose.invoke // SpoilerOverlay.Solid(cornerRadius: Dp)
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlay

EnrichedMarkdownText(
  markdown = "The butler did it: ||it was the gardener||.",
  spoilerOverlay = SpoilerOverlay.Solid(cornerRadius = 6.dp),
)

EnrichedMarkdownText(
  markdown = "||A denser, faster field.||",
  spoilerOverlay = SpoilerOverlay.Particles(density = 12f, speed = 30f),
)
```

The view rebuilds its overlays only when the new value is not `==` to the previous one. The built-ins are data classes, so constructing them inline on every recomposition is fine.

#### Custom overlays {#custom-spoiler-overlays}

Implement `CustomSpoilerOverlay` to draw your own effect. It builds one overlay per *slice* - the part of a spoiler on one line - and in Compose the easiest base class is `DrawScopeSpoilerSliceOverlay`, which hands you a `DrawScope` clipped to the slice. The text under the slice is already transparent, so no backdrop is needed.

```kotlin
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import com.swmansion.enriched.markdown.compose.DrawScopeSpoilerSliceOverlay
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.spoiler.CustomSpoilerOverlay
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlayHost
import com.swmansion.enriched.markdown.spoiler.SpoilerSlice
import com.swmansion.enriched.markdown.spoiler.SpoilerSliceOverlay
import com.swmansion.enriched.markdown.styles.SpoilerStyle

data object FlatSpoiler : CustomSpoilerOverlay {
  override fun createSliceOverlay(
    host: SpoilerOverlayHost,
    style: SpoilerStyle,
  ): SpoilerSliceOverlay =
    object : DrawScopeSpoilerSliceOverlay(host) {
      override fun DrawScope.draw(slice: SpoilerSlice) {
        drawRect(Color(style.color))
      }
    }
}

EnrichedMarkdownText(
  markdown = "||Hidden until tapped.||",
  spoilerOverlay = FlatSpoiler,
)
```

- Make implementations a `data class` or `object`. A plain class created anew on each recomposition is never `==` to the last one, so every overlay restarts each time.
- `createSliceOverlay` runs on the main thread whenever a slice comes into view - first draw, reflow, an image under it loading, an overlay or style change. Keep it cheap.
- On reveal, the default fades `draw` out over `revealDurationMillis` (450 ms by default) while the text fades in. Override `drawReveal` for a different reveal, and `isAnimated` to get a draw every frame (read `slice.frameTimeMillis`).
- `drawSliceText(slice)` draws the slice's revealed text, for effects that show the text through, like a blur. It lays out the whole line each call, so cache the result.

### `includeLastBlockMargin` {#includelastblockmargin}

Whether the view keeps the bottom margin of its last block. By default the view ends flush with its last line, so it sits tight against whatever comes next. Turn this on when you stack several `EnrichedMarkdownText` composables one after another and want the gap between them to match the spacing between blocks inside one.

<PropInfo type="Boolean" default="false" />

```kotlin
import androidx.compose.foundation.layout.Column
import androidx.compose.runtime.Composable
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText

@Composable
fun Sections(sections: List<String>) {
  Column {
    sections.forEach { section ->
      EnrichedMarkdownText(markdown = section, includeLastBlockMargin = true)
    }
  }
}
```

Toggling it only re-lays out the view; nothing is re-rendered.

### `plugins` {#plugins}

The plugins this view renders with. A plugin adds rendering the core library does not have - today that is LaTeX math, from the `math` artifact, and syntax highlighting for code blocks, from the [`code-highlight`](/android/guides/code-highlighting) artifact. The default reads `LocalMarkdownPlugins.current`, the plugins enabled by the enclosing scopes, so you usually enable plugins with a scope rather than this parameter.

<PropInfo type="List<MarkdownPlugin>" default="LocalMarkdownPlugins.current" />

Wrap a subtree in `MarkdownPlugins(...)` to enable plugins for every `EnrichedMarkdownText` inside it. Plugin artifacts ship a shorthand scope named after the plugin, so `LatexMathPlugin { ... }` is the same as `MarkdownPlugins(LatexMathPlugin) { ... }`, and `CodeHighlightPlugin { ... }` the same as `MarkdownPlugins(CodeHighlightPlugin) { ... }`:

```kotlin
import androidx.compose.runtime.Composable
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.math.LatexMathPlugin

@Composable
fun MathScreen() {
  LatexMathPlugin {
    EnrichedMarkdownText(markdown = "Euler: \$e^{i\\pi} + 1 = 0\$")
  }
}
```

Scopes nest independently of [`MarkdownTheme`](/android/api-reference/markdown-theme). A plugin enabled in an inner scope replaces one with the same id from an outer scope, and where several plugins claim the same node the innermost wins. Passing `plugins` directly overrides the scopes for that one view - `plugins = emptyList()` turns them all off.

Enabling `LatexMathPlugin` is all math needs: it turns on parsing `$...$` and `$$...$$` for the views it reaches, so there is no option to set alongside it. `LatexMathPlugin(accessibilityLabel = …)` is the same plugin with a different TalkBack label for formulas - see [Accessibility](/android/guides/latex-math#accessibility). See [LaTeX math](/android/guides/latex-math). Code highlighting needs no option either - fenced code is always parsed with its language. See [Code highlighting](/android/guides/code-highlighting).

## Callbacks

### `onLinkClick` {#onlinkclick}

Called with the URL when the reader taps a link. Links do nothing until you handle this - the library never opens a URL on your behalf.

<PropInfo type="(String) -> Unit" default="{}" />

```kotlin
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText

@Composable
fun Article(content: String) {
  val context = LocalContext.current

  EnrichedMarkdownText(
    markdown = content,
    onLinkClick = { url ->
      try {
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
      } catch (e: ActivityNotFoundException) {
        // A relative link or an unknown scheme has no app to open it.
      }
    },
  )
}
```

The URL is passed exactly as written in the source, so a relative link like `[docs](./guide.md)` arrives unresolved.

### `onLinkLongClick`

Called with the URL when the reader long-presses a link - the usual hook for a "copy link" or share sheet.

<PropInfo type="(String) -> Unit" default="{}" />

```kotlin
import android.content.ClipData
import android.content.ClipboardManager
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText

@Composable
fun CopyableLinks(content: String) {
  val context = LocalContext.current

  EnrichedMarkdownText(
    markdown = content,
    onLinkLongClick = { url ->
      val clipboard = context.getSystemService(ClipboardManager::class.java)
      clipboard.setPrimaryClip(ClipData.newPlainText("Link", url))
    },
  )
}
```

### `onTaskListItemToggle` {#ontasklistitemtoggle}

Called after a task list checkbox tap toggles the item. Not called when [`taskListToggleEnabled`](#tasklisttoggleenabled) is `false`.

<PropInfo type="(TaskListItemToggle) -> Unit" default="{}" />

```kotlin
data class TaskListItemToggle(
  val index: Int,       // 0-based, in document order
  val checked: Boolean, // state after the toggle
  val text: String,     // first line of the item's plain text
)
```

```kotlin
import androidx.compose.runtime.Composable
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText

@Composable
fun Checklist(
  source: String,
  onItemChecked: (index: Int, checked: Boolean) -> Unit,
) {
  EnrichedMarkdownText(
    markdown = source,
    onTaskListItemToggle = { toggle -> onItemChecked(toggle.index, toggle.checked) },
  )
}
```

The toggle is **visual only**. The view never rewrites the `markdown` string you passed it, so persist the change from the handler if it has to survive a new source string. Re-supplying the *same* string on recomposition keeps the toggles as the reader left them; any different string drops them.

### `onPluginEvent` {#onpluginevent}

Receives events reported by installed [plugins](#plugins) - for example a formula the math plugin could not typeset. Check the event's type to see which plugin sent it.

<PropInfo type="(PluginEvent) -> Unit" default="{}" />

```kotlin
interface PluginEvent {
  val pluginId: String
}
```

The math plugin reports `LatexError` (from `com.swmansion.enriched.markdown.math`) when an expression fails; the expression is shown as its raw source instead.

```kotlin
data class LatexError(
  val source: String,       // the failing expression, without its $ / $$ delimiters
  val message: String?,     // the engine's error, when it gave one
  val displayMode: Boolean, // false for $...$, true for $$...$$
  override val pluginId: String = LatexMathPlugin.ID,
) : PluginEvent
```

```kotlin
import android.util.Log
import androidx.compose.runtime.Composable
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.math.LatexError
import com.swmansion.enriched.markdown.math.LatexMathPlugin

@Composable
fun Answer(markdown: String) {
  LatexMathPlugin {
    EnrichedMarkdownText(
      markdown = markdown,
      onPluginEvent = { event ->
        if (event is LatexError) Log.w("Answer", "Bad LaTeX: ${event.source} (${event.message})")
      },
    )
  }
}
```

Events arrive on the main thread. Each distinct event is reported **once** per view while `markdown` only grows, so streamed text that re-renders the same broken formula on every token reports it a single time. Replacing `markdown` with a string that does not start with the previous one resets that, and the events are reported again.

### `onCodeBlockCopy` {#oncodeblockcopy}

Called after a code block's code is copied: by its copy button, or by **Copy** in its long-press menu. Not called for **Copy as Markdown**, or for a block with no code, which leaves the clipboard as it was. Only [`CodeBlockLayout.Scrollable`](#codeblocklayout) blocks have a copy button and menu; a wrapping block copies through the text selection, which does not call this.

<PropInfo type="(CodeBlockCopy) -> Unit" default="{}" />

```kotlin
data class CodeBlockCopy(
  val code: String,      // what went to the clipboard
  val language: String?, // the fence's info string, null when it named none
)
```

```kotlin
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import com.swmansion.enriched.markdown.compose.CodeBlockLayout
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import kotlinx.coroutines.launch

@Composable
fun Snippet(content: String, snackbarHostState: SnackbarHostState) {
  val scope = rememberCoroutineScope()

  EnrichedMarkdownText(
    markdown = content,
    codeBlockLayout = CodeBlockLayout.Scrollable,
    onCodeBlockCopy = { scope.launch { snackbarHostState.showSnackbar("Copied") } },
  )
}
```

## See also

- [Style properties](/android/api-reference/style-properties) - every styleable element and property.
- [`MarkdownTheme`](/android/api-reference/markdown-theme) - providing and layering styles.
- [Element structure](/android/api-reference/element-structure) - what each Markdown construct renders as.
- [LaTeX math](/android/guides/latex-math) - setting up the math plugin.
- [Code highlighting](/android/guides/code-highlighting) - setting up the code-highlight plugin.
