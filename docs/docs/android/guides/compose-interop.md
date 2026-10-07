---
sidebar_label: Compose interop
sidebar_position: 3
---

# Compose interop

`EnrichedMarkdownText` is a composable, but it is not *made of* composables. Underneath it is a native `TextView` subclass hosted through [`AndroidView`](https://developer.android.com/develop/ui/compose/migrate/interoperability-apis), because Markdown rendering leans on Android's span and text-layout machinery - which is also what buys you real text selection, TalkBack, and system font scaling for free.

That interop boundary is invisible most of the time. This guide covers the places it isn't.

## It renders nothing in `@Preview`

Compose previews do not instantiate real Android views, so a preview containing `EnrichedMarkdownText` renders an empty space. Nothing is wrong and nothing is logged - there is simply no view to draw.

Preview the layout **around** the Markdown by standing in a `Text` or a placeholder `Box` of roughly the right size, and check the Markdown itself on a device or emulator.

## Sizing

The composable measures like the view it wraps: it fills the width it is given and takes the height its content needs. Constrain it with the [`modifier`](/android/api-reference/enriched-markdown-text#modifier) as you would any other composable:

```kotlin
EnrichedMarkdownText(
  markdown = content,
  modifier = Modifier
    .fillMaxWidth()
    .padding(horizontal = 16.dp),
)
```

Use the modifier for the box - padding, background, borders, click targets around the text. Use [`markdownStyle`](/android/api-reference/style-properties) for the text itself; the per-element `marginTop` / `marginBottom` properties handle spacing *between* Markdown blocks, which a modifier cannot reach.

A long document is one tall view, so put it in a `verticalScroll` container if it can exceed the screen.

## Inside a `LazyColumn`

Rendering one `EnrichedMarkdownText` per row works, with one caveat that bites: **views are recycled**, and recycling resets a row's interaction state.

Task list checkboxes are the visible case. A tap toggles a checkbox in place without rewriting your `markdown` string, so the toggle lives in the view - and when that view is reused for another row, it is cleared. A checkbox the reader ticked can come back unticked after scrolling away and back.

The fix is the one you would apply to any recycled row: **hoist the state**. Record the change in [`onTaskListItemPress`](/android/api-reference/enriched-markdown-text#ontasklistitempress) and feed it back through the `markdown` string you pass:

```kotlin
EnrichedMarkdownText(
  markdown = item.markdown,
  onTaskListItemPress = { event -> viewModel.setDone(item.id, event.index, event.checked) },
)
```

Give each row a stable `key` as well, so Compose reuses views for the rows you mean.

## Selection is per component

Each `EnrichedMarkdownText` is its own selection scope. Within one, a selection can run the whole document - headings, quotes, and code blocks included, since a document renders into a single text view. Across two, it cannot: there is no way to drag a selection from one component into the next, and Compose's `SelectionContainer` does not bridge them.

So if a screen's text should be selectable as one unit, render it as **one** `EnrichedMarkdownText` with one Markdown string, rather than composing several.

Copying a selection yields its **Markdown source**, not the rendered plain text - a copied heading arrives as `# Heading`.

## Recomposition and the cost of styles

Resolving a [`MarkdownStyle`](/android/api-reference/markdown-theme) is real work: layers are flattened and every `sp`, `Dp`, `Color`, and `FontFamily` is converted against the current density and font resolver. It happens **off the main thread**, and the first frame paints with defaults until it completes.

Two habits keep that off your critical path:

- **Hoist styles to file scope.** A style built inside a composable body is reallocated on every recomposition. Equal layers do compare equal, so nothing re-resolves - but `MarkdownTheme` is backed by a *static* composition local, where an unstable value recomposes the entire subtree rather than just its readers.
- **Use [`rememberMarkdownStyle`](/android/api-reference/markdown-theme#remembermarkdownstyle) when the style reads `MaterialTheme`.** It rebuilds on a color-scheme change and reuses the result otherwise.

Changing `markdown` or [`flags`](/android/api-reference/enriched-markdown-text#flags) re-parses the document, so treat both as content rather than as values to churn per frame. A configuration change - rotation, theme switch, font-size change - re-renders too, because layout depends on the width and density it was measured at.

## Accessibility

The view exposes its structure to TalkBack rather than announcing one undifferentiated blob of text: headings, links, list items, images, and admonition headers each surface as their own accessible node, with list items announced with their position. Readers can navigate a document by element the way they would any native screen.

System font scaling applies automatically, since the underlying view participates in it like any other text.

For what accessibility support looks like across the library, see [Accessibility](/user-experience/accessibility).
