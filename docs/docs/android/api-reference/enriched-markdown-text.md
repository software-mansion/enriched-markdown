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
  flags: Md4cFlags = Md4cFlags.DEFAULT,
  selectable: Boolean = true,
  imageRequestHeaders: Map<String, String> = emptyMap(),
  onLinkPress: ((String) -> Unit)? = null,
  onLinkLongPress: ((String) -> Unit)? = null,
  onTaskListItemPress: ((TaskListItemPressEvent) -> Unit)? = null,
  enableTaskListItemToggle: Boolean = true,
)
```

:::note
The composable wraps a real Android `View` through `AndroidView`, so it renders **nothing** in `@Preview`. Run it on a device or emulator.
:::

## Parameters

### `markdown`

The Markdown source to render. Which syntax is recognized depends on [`flags`](#flags) - see [Feature support](/introduction/supported-features) for the full matrix and [Element structure](/android/api-reference/element-structure) for what each element renders as.

<PropInfo type="String" required />

### `modifier`

The Compose [`Modifier`](https://developer.android.com/develop/ui/compose/modifiers) applied to the wrapping `AndroidView`. Use it for layout and decoration around the text - `fillMaxWidth`, `padding`, `background`, and so on. To style the Markdown itself, use [`style`](#style).

<PropInfo type="Modifier" default="Modifier" />

### `style`

A per-instance style override. Defaults to the style provided by the nearest [`MarkdownTheme`](/android/api-reference/markdown-theme), so you usually set this only when one component needs to differ from its surroundings. Build one with the `markdownStyle { }` DSL - see [Style properties](/android/api-reference/style-properties).

<PropInfo type="MarkdownStyle" default="MarkdownTheme.style" />

### `flags`

Toggles for md4c's parser extensions. Each one opts a piece of extra syntax in or out; pass only the flags you want to change and the rest keep their defaults.

<PropInfo type="Md4cFlags" default="Md4cFlags.DEFAULT" />

```kotlin
data class Md4cFlags(
  val underline: Boolean = false,
  val latexMath: Boolean = false,
  val superscript: Boolean = false,
  val subscript: Boolean = false,
  val highlight: Boolean = false,
  val permissiveAutolinks: Boolean = true,
  val hardSoftBreaks: Boolean = false,
  val preserveBlankLines: Boolean = false,
  val admonitions: Boolean = false,
)
```

```kotlin
EnrichedMarkdownText(
  markdown = content,
  flags = Md4cFlags(underline = true, admonitions = true),
)
```

:::note
`Md4cFlags.DEFAULT` turns **everything off except `permissiveAutolinks`**.
:::

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

Parses `==text==` as a highlight node.

<PropInfo type="Boolean" default="false" />

:::danger
**Leave this off.** The parser emits the node, but Android has no highlight renderer, and an unrendered node's text is **dropped from the output** rather than shown unmarked - so `==text==` renders as nothing at all, with a `No renderer for: Highlight` warning in Logcat. With the flag off, the `==` markers stay literal text and nothing is lost. See the [roadmap](/misc/roadmap).
:::

#### `latexMath`

Parses `$inline$` and `$$block$$` as math nodes.

<PropInfo type="Boolean" default="false" />

:::danger
**Leave this off.** The parser emits the nodes, but Android has no math renderer, and an unrendered node's text is **dropped from the output** - so a formula renders as nothing at all, with a `No renderer for: LatexMathInline` warning in Logcat. With the flag off, the `$` stays literal text and the formula is at least readable. See the [roadmap](/misc/roadmap).
:::

#### `permissiveAutolinks`

Links bare URLs. Plain Markdown only autolinks a URL wrapped in angle brackets - `<https://swmansion.com>` - so with this off, a URL pasted on its own stays inert text. With it on, `https://swmansion.com` becomes a link as written.

This is separate from `[text](url)`, which is an ordinary inline link and always works. The flag is the one extension that is **on** by default.

<PropInfo type="Boolean" default="true" />

#### `hardSoftBreaks`

Treats a single newline as a hard line break, so lines inside one paragraph keep the breaks you typed instead of reflowing. See [Line breaks](/android/api-reference/element-structure#line-breaks).

<PropInfo type="Boolean" default="false" />

#### `preserveBlankLines`

Keeps consecutive blank lines instead of collapsing them, so vertical whitespace in the source survives into the output.

<PropInfo type="Boolean" default="false" />

#### `admonitions`

Renders a blockquote whose first line is `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, or `> [!CAUTION]` as a themed callout with an icon and a title. Without it the marker stays literal text inside an ordinary quote. Colors come from the [`admonitions`](/android/api-reference/style-properties#admonitions) block.

<PropInfo type="Boolean" default="false" />

### `selectable`

Whether the reader can select and copy text. Copying reproduces the **Markdown source** of the selection, not the rendered plain text.

<PropInfo type="Boolean" default="true" />

:::note
A document renders into a single text view, so a selection can run across the whole document - headings, quotes, and code blocks included. It cannot span **two** `EnrichedMarkdownText` composables, though: each one is its own selection scope.
:::

### `imageRequestHeaders`

HTTP headers attached to **remote** image requests - an `Authorization` token, a `Referer`, and so on. They apply to every image the document loads.

<PropInfo type="Map<String, String>" default="emptyMap()" />

```kotlin
EnrichedMarkdownText(
  markdown = content,
  imageRequestHeaders = mapOf("Authorization" to "Bearer $token"),
)
```

Headers take part in the cache key, so the same URL fetched with different headers is cached separately - see [Image caching](/android/guides/image-caching).

### `enableTaskListItemToggle`

Whether tapping a task list checkbox toggles it. With `false`, checkbox taps are fully inert: no visual toggle and no [`onTaskListItemPress`](#ontasklistitempress). Text selection and links are unaffected either way.

<PropInfo type="Boolean" default="true" />

## Callbacks

### `onLinkPress`

Called with the URL when the reader taps a link. Links do nothing until you handle this - the library never opens a URL on your behalf.

<PropInfo type="((String) -> Unit)?" default="null" />

```kotlin
val context = LocalContext.current

EnrichedMarkdownText(
  markdown = content,
  onLinkPress = { url ->
    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
  },
)
```

### `onLinkLongPress`

Called with the URL when the reader long-presses a link - the usual hook for a "copy link" or share sheet.

<PropInfo type="((String) -> Unit)?" default="null" />

### `onTaskListItemPress`

Called after a task list checkbox tap toggles the item. Not called when [`enableTaskListItemToggle`](#enabletasklistitemtoggle) is `false`.

<PropInfo type="((TaskListItemPressEvent) -> Unit)?" default="null" />

```kotlin
data class TaskListItemPressEvent(
  val index: Int,       // 0-based, in document order
  val checked: Boolean, // state after the toggle
  val text: String,     // first line of the item's plain text
)
```

```kotlin
EnrichedMarkdownText(
  markdown = checklist,
  onTaskListItemPress = { event -> store.setDone(event.index, event.checked) },
)
```

The toggle is **visual only**. The view never rewrites the `markdown` string you passed it, so persist the change from the handler if it has to survive a new source string. Re-supplying the *same* string on recomposition keeps the toggles as the reader left them.

## See also

- [Style properties](/android/api-reference/style-properties) - every styleable element and property.
- [`MarkdownTheme`](/android/api-reference/markdown-theme) - providing and layering styles.
- [Element structure](/android/api-reference/element-structure) - what each Markdown construct renders as.
