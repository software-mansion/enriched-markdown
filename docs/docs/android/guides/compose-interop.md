---
sidebar_label: Compose interop
sidebar_position: 3
---

# Compose interop

`EnrichedMarkdownText` is a composable, but it is not *made of* composables. Underneath it is a native Android view hosted through [`AndroidView`](https://developer.android.com/develop/ui/compose/migrate/interoperability-apis): a container that stacks one child view per **segment** of the document. Runs of ordinary blocks - paragraphs, headings, lists, quotes, code blocks - render into a `TextView` segment, while each top-level table, and each block a plugin draws (such as display math), gets a view of its own between them. Markdown rendering leans on Android's span and text-layout machinery, which is also what buys you real text selection, TalkBack, and system font scaling for free.

That interop boundary is invisible most of the time. This guide covers the places it isn't.

## It renders nothing in `@Preview`

The preview renderer does create the hosted view, but the Markdown parser is a native (JNI) library, and that library is not available inside a Compose preview. Loading it fails - the failure is logged under the `MarkdownParser` tag - no document is ever parsed, and the component collapses to zero height. Nothing is wrong with your code; the preview simply cannot run the parser.

Preview the layout **around** the Markdown by standing in a `Text` or a placeholder `Box` of roughly the right size, and check the Markdown itself on a device or emulator.

## Sizing

The composable measures like the view it wraps: it takes the height its content needs, and its width **wraps** its content - the widest segment, capped by the width available - unless you give it an exact width. A short paragraph without `fillMaxWidth()` is only as wide as its text. Constrain it with the [`modifier`](/android/api-reference/enriched-markdown-text#modifier) as you would any other composable:

```kotlin
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText

@Composable
fun Article(content: String) {
  EnrichedMarkdownText(
    markdown = content,
    modifier = Modifier
      .fillMaxWidth()
      .padding(horizontal = 16.dp),
  )
}
```

Use the modifier for the box - padding, background, borders, click targets around the text. Use the [`style`](/android/api-reference/enriched-markdown-text#style) parameter (or an enclosing [`MarkdownTheme`](/android/api-reference/markdown-theme)) for the text itself; the per-element `marginTop` / `marginBottom` [style properties](/android/api-reference/style-properties) handle spacing *between* Markdown blocks, which a modifier cannot reach.

By default the last block's bottom margin is dropped, so the component ends flush with its last line. When you stack several `EnrichedMarkdownText` components one after another, turn on [`includeLastBlockMargin`](/android/api-reference/enriched-markdown-text#includelastblockmargin) so each keeps the same spacing that separates blocks inside a document.

A long document is one tall view, so put it in a `verticalScroll` container if it can exceed the screen.

## Inside a `LazyColumn`

Rendering one `EnrichedMarkdownText` per row works, with one caveat that bites: **views are recycled**, and recycling resets a row's interaction state. When a row scrolls out, its view is cleared and may be handed to another row; scrolling back renders the row's `markdown` from scratch. Everything the reader did to the old view is gone:

- **Task list checkboxes.** A tap toggles a checkbox in place without rewriting your `markdown` string, so the toggle lives in the view. A checkbox the reader ticked comes back unticked after scrolling away and back. Passing a *different* `markdown` string drops the toggles too; passing the same string again keeps them.
- **Spoilers.** A revealed `||spoiler||` is concealed again. The reveal is not reported to your code, so there is no state to hoist.
- **Selection.** An active text selection is lost.

For checkboxes, the fix is the one you would apply to any recycled row: **hoist the state**. Record the change in [`onTaskListItemToggle`](/android/api-reference/enriched-markdown-text#ontasklistitemtoggle) and feed it back through the `markdown` string you pass. The callback reports the item's 0-based `index` among the document's task items, in document order, and its `checked` state after the tap; rewrite that item's `[ ]` / `[x]` marker in your stored source:

```kotlin
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText

data class Note(val id: String, val markdown: String)

@Composable
fun NoteList(
  notes: List<Note>,
  onTaskToggled: (noteId: String, index: Int, checked: Boolean) -> Unit,
) {
  LazyColumn {
    items(notes, key = { it.id }) { note ->
      EnrichedMarkdownText(
        markdown = note.markdown,
        onTaskListItemToggle = { toggle -> onTaskToggled(note.id, toggle.index, toggle.checked) },
      )
    }
  }
}
```

Give each row a stable `key` as well, so a row's content stays matched to the right item when the list changes. A key does **not** keep a view alive or preserve its state across scrolling - only hoisted state survives that.

## Selection is per component

A selection lives inside one `TextView` segment. Within a segment it can run freely across headings, quotes, lists, and code blocks. It **stops at a table or a plugin block**, which are separate views: a document with a table in the middle has one selectable run above the table and another below it, and a selection cannot be dragged across. Tables are not text-selectable at all - long-press one for a menu that copies the whole table.

The same holds between components, only more so: there is no way to drag a selection from one `EnrichedMarkdownText` into the next, and Compose's `SelectionContainer` does not bridge them. So if a screen's text should be selectable as one unit, render it as **one** `EnrichedMarkdownText` with one Markdown string, rather than composing several.

The selection menu offers two copy actions:

- **Copy** puts the rendered **plain text** on the clipboard, together with an **HTML** version that keeps the formatting for apps that paste rich text.
- **Copy as Markdown** is a separate menu item that copies the selection's **Markdown source** - a copied heading arrives as `# Heading`.

## Recomposition and the cost of styles

Resolving a [`MarkdownStyle`](/android/api-reference/markdown-theme) is real work: layers are flattened and every `sp`, `Dp`, `Color`, and `FontFamily` is converted against the current density and font resolver. It happens **off the main thread**, and so does parsing and rendering the document itself. The first frame therefore has nothing to show: the component is laid out at **zero height**, and grows to its real height once the render lands a frame or more later. A screen of several components fills in as each one finishes, and in a `LazyColumn` rows that scroll in grow after they appear - so content below them can jump. Reserve space around the component (a `heightIn(min = …)` on the modifier, say) if that shift matters on your screen.

Two habits keep that off your critical path:

- **Hoist styles to file scope.** A style built inside a composable body is reallocated on every recomposition. Equal layers do compare equal, so nothing re-resolves - but `MarkdownTheme` is backed by a *static* composition local, where an unstable value recomposes the entire subtree rather than just its readers.
- **Use [`rememberMarkdownStyle`](/android/api-reference/markdown-theme#remembermarkdownstyle) when the style reads `MaterialTheme`.** It rebuilds on a color-scheme change and reuses the result otherwise.

Changing `markdown` or [`flags`](/android/api-reference/enriched-markdown-text#flags) re-parses the document, so treat both as content rather than as values to churn per frame. A configuration change - rotation, theme switch, font-size change - re-renders too, because layout depends on the width and density it was measured at.

## Accessibility

The view exposes its structure to TalkBack rather than announcing one undifferentiated blob of text: headings, links, list items, images, and admonition headers each surface as their own accessible node. List items say what they are - an ordered item is announced with its number ("list item 2"), a bullet as a bullet point, a task item with its checked state, and a nested item as nested. Readers can navigate a document by element the way they would any native screen.

System font scaling applies automatically, since the underlying view participates in it like any other text.

For what accessibility support looks like across the library, see [Accessibility](/user-experience/accessibility).
