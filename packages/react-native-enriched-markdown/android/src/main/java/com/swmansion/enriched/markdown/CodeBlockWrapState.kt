package com.swmansion.enriched.markdown

import com.swmansion.enriched.markdown.segments.CodeBlockContainerView

// Code block wrap state is keyed by block position, so it only stays meaningful
// while the document grows in place. Streaming may rewrite its unfinished last
// line (an HTML tag closing, a link relabeled); anything earlier changing - a
// recycled cell, an edited message, a block inserted above - starts unwrapped.
// Compares in place: this runs on every streamed chunk while a block is wrapped.
internal fun keepsCodeBlockWrapState(
  previous: String,
  next: String,
): Boolean {
  val cut = previous.lastIndexOf('\n')
  return cut < 0 || next.regionMatches(0, previous, 0, cut)
}

/**
 * Which code blocks of one EnrichedMarkdown the user wrapped with the header
 * toggle, and the only writer of that choice.
 *
 * Blocks are identified by document-order index, counted pre-order across
 * nesting (a block inside a blockquote takes the next index, like a top-level
 * one); [CodeBlockWrapCursor] counts the same way in the view-free measure
 * pass. The set lives here rather than on the views, which are rebuilt on
 * style and font-scale changes, and is mirrored into MeasurementStore under the
 * view tag for that measure pass.
 */
internal class CodeBlockWrapState(
  private val viewTag: () -> Int,
  private val codeBlockViews: () -> Sequence<CodeBlockContainerView>,
  private val onHeightChanged: () -> Unit,
) {
  // Matches the prop's default, for a host that never receives the prop.
  var enabled: Boolean = true
    private set

  var indices: Set<Int> = emptySet()
    private set

  // The markdown prop as last received, which local task toggles don't touch.
  private var lastMarkdownProp: String = ""

  /** Returns whether the wrapped set was cleared, so the height must be recomputed. */
  fun setEnabled(value: Boolean): Boolean {
    if (enabled == value) return false
    enabled = value
    val cleared = !value && indices.isNotEmpty()
    if (cleared) write(emptySet())
    sync()
    return cleared
  }

  /**
   * Applies the reset rule to a new markdown prop; [rendered] is the document on
   * screen, which includes local task toggles. The prop is compared with the
   * previous prop, so an app that ignores a checkbox tap and keeps streaming its
   * own copy keeps the wrapped blocks; a prop equal to what's rendered is the app
   * echoing a task toggle back and keeps them too. Returns whether the wrapped
   * set was cleared.
   */
  fun onMarkdownProp(
    next: String,
    rendered: String,
  ): Boolean {
    val previous = lastMarkdownProp
    lastMarkdownProp = next
    if (indices.isEmpty() || next == rendered || keepsCodeBlockWrapState(previous, next)) return false
    write(emptySet())
    return true
  }

  /** Pushes the wrapped set and the toggle onto the current code block views. */
  fun sync() {
    codeBlockViews().forEachIndexed { index, view ->
      view.onWrapToggle = ::toggle
      view.showsWrapButton = enabled
      view.wrapped = enabled && index in indices
    }
  }

  private fun toggle(view: CodeBlockContainerView) {
    if (!enabled) return
    val index = codeBlockViews().indexOf(view)
    if (index < 0) return
    write(if (index in indices) indices - index else indices + index)
    sync()
    onHeightChanged()
  }

  private fun write(value: Set<Int>) {
    indices = value
    MeasurementStore.updateWrappedCodeBlocks(viewTag(), value)
  }
}

/**
 * Hands out the wrapped flag of each code block in the order a view-free measure
 * pass reaches them: pre-order, descending into blockquotes, the same order
 * [CodeBlockWrapState] indexes the views in.
 */
class CodeBlockWrapCursor(
  private val wrapped: Set<Int>,
) {
  private var nextIndex = 0

  fun nextIsWrapped(): Boolean = nextIndex++ in wrapped
}
