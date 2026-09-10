package com.swmansion.enriched.markdown.utils.text.interaction

import android.text.Layout
import android.text.Spannable
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.StrikethroughSpan
import android.widget.TextView
import com.swmansion.enriched.markdown.spans.BaseListSpan
import com.swmansion.enriched.markdown.spans.CodeBlockSpan
import com.swmansion.enriched.markdown.spans.TaskListSpan
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE

/** The task item under a tap: the span drawing it, its state *before* the tap, and its first line of text. */
data class TaskListHitTestResult(
  val span: TaskListSpan,
  val checked: Boolean,
  val itemText: String,
) {
  val taskIndex: Int get() = span.taskIndex
}

object TaskListToggleUtils {
  private val TASK_PATTERN = Regex("""^[ \t]*[-*+][ \t]+\[[ xX]]""", RegexOption.MULTILINE)

  /**
   * Rewrites [markdown]'s `- [ ]` / `- [x]` markers to the states in
   * [checkedStates], keyed by task index. The pattern scans top-down, so its
   * indices line up with the renderer's document-order task indices; an index
   * the document does not have is ignored.
   */
  fun applyCheckedStates(
    markdown: String,
    checkedStates: Map<Int, Boolean>,
  ): String {
    if (checkedStates.isEmpty()) return markdown

    // A marker's state character is the second to last of its match and its
    // replacement is one character wide too, so a single scan rewrites every
    // marker in place, without shifting the offsets of the ones after it.
    val rewritten = StringBuilder(markdown)
    TASK_PATTERN.findAll(markdown).forEachIndexed { index, match ->
      val checked = checkedStates[index] ?: return@forEachIndexed
      rewritten.setCharAt(match.range.last - 1, if (checked) 'x' else ' ')
    }

    return rewritten.toString()
  }
}

object TaskListTapUtils {
  /**
   * The task item whose checkbox margin contains ([rawX], [rawY]) in view
   * coordinates, or `null`. The whole leading margin of the item's paragraph is
   * tappable, not just the drawn box.
   */
  fun hitTest(
    textView: TextView,
    rawX: Float,
    rawY: Float,
  ): TaskListHitTestResult? =
    with(textView) {
      val layout = layout ?: return null
      val spannable = text as? Spanned ?: return null

      val x = rawX.toInt() - totalPaddingLeft + scrollX
      val y = rawY.toInt() - totalPaddingTop + scrollY

      // getLineForVertical clamps, so a tap in the padding above or below the
      // laid-out text would otherwise hit the first or last line's checkbox.
      if (y < 0 || y > layout.height) return null

      val line = layout.getLineForVertical(y)

      // The innermost list span owns the line's margin, so a tap in a nested
      // plain item's indent belongs to that item, not to its task-list parent.
      val taskSpan =
        spannable
          .getSpans(
            layout.getLineStart(line),
            layout.getLineEnd(line),
            BaseListSpan::class.java,
          ).maxByOrNull { it.depth } as? TaskListSpan ?: return null

      val isRtl = layout.getParagraphDirection(line) == Layout.DIR_RIGHT_TO_LEFT
      if (isRtl) {
        val lineRight = layout.getLineRight(line).toInt()
        val indentWidth = lineRight - layout.getParagraphRight(line)
        if (x <= layout.width - indentWidth) return null
      } else {
        val lineLeft = layout.getLineLeft(line).toInt()
        val indentWidth = layout.getParagraphLeft(line) - lineLeft
        if (x >= indentWidth) return null
      }

      val spanStart = spannable.getSpanStart(taskSpan)
      val spanEnd = spannable.getSpanEnd(taskSpan)

      val itemText =
        spannable
          .subSequence(spanStart, spanEnd)
          .toString()
          .substringBefore('\n')
          .trim()

      return TaskListHitTestResult(
        span = taskSpan,
        checked = taskSpan.isChecked,
        itemText = itemText,
      )
    }

  /**
   * Flips [span]'s checkbox and checked-text decoration directly on [textView]'s
   * spans — no re-parse, so a tap redraws immediately.
   *
   * Returns `false` when the view holds no spannable text or [span] is no longer
   * attached to it, which a render landing mid-gesture can do; the caller then
   * has to fall back to re-rendering the markdown source.
   */
  fun updateTaskListItemCheckedState(
    textView: TextView,
    span: TaskListSpan,
    newChecked: Boolean,
    styleConfig: StyleConfig,
  ): Boolean {
    val spannable = textView.text as? Spannable ?: return false

    val spanStart = spannable.getSpanStart(span)
    val spanEnd = spannable.getSpanEnd(span)
    if (spanStart < 0) return false

    if (span.isChecked == newChecked) return true

    // Flip the span in place, then re-set it over the range it already holds.
    // Re-setting an attached span keeps its slot in the buffer's span array —
    // Layout paints LeadingMarginSpans in that order, advancing x by each one's
    // margin, so a remove + add would send this span to the end and a nested
    // item would draw its checkbox an indent too far right, over its own text.
    // The setSpan still reports a span change, and that is what makes TextView
    // drop the render node its Editor caches the drawn text in; a bare
    // invalidate() re-runs onDraw off that cache and repaints the old checkbox.
    span.isChecked = newChecked
    spannable.setSpan(span, spanStart, spanEnd, spannable.getSpanFlags(span))

    // Nested items and code blocks keep their own styling, exactly as on the
    // initial render in ListItemRenderer.
    val excludedRanges =
      (
        spannable.getSpans(spanStart, spanEnd, BaseListSpan::class.java).filter { it.depth > span.depth } +
          spannable.getSpans(spanStart, spanEnd, CodeBlockSpan::class.java).toList()
      ).map { spannable.getSpanStart(it) to spannable.getSpanEnd(it) }
        .sortedBy { it.first }

    applyDecorationsToRanges(
      spannable = spannable,
      spanStart = spanStart,
      spanEnd = spanEnd,
      excludedRanges = excludedRanges,
      isChecked = newChecked,
      styleConfig = styleConfig,
    )

    textView.invalidate()

    return true
  }

  private fun applyDecorationsToRanges(
    spannable: Spannable,
    spanStart: Int,
    spanEnd: Int,
    excludedRanges: List<Pair<Int, Int>>,
    isChecked: Boolean,
    styleConfig: StyleConfig,
  ) {
    val checkedTextColor = styleConfig.taskListStyle.checkedTextColor
    val strikethrough = styleConfig.taskListStyle.checkedStrikethrough

    fun decorate(
      start: Int,
      end: Int,
    ) {
      if (isChecked) {
        applyCheckedSpans(spannable, start, end, checkedTextColor, strikethrough)
      } else {
        removeCheckedSpans(spannable, start, end)
      }
    }

    var currentPos = spanStart
    for ((start, end) in excludedRanges) {
      if (start > currentPos) {
        decorate(currentPos, start)
      }
      currentPos = maxOf(currentPos, end)
    }
    if (currentPos < spanEnd) {
      decorate(currentPos, spanEnd)
    }
  }

  private fun applyCheckedSpans(
    spannable: Spannable,
    start: Int,
    end: Int,
    color: Int,
    strikethrough: Boolean,
  ) {
    if (color != 0) {
      spannable.setSpan(ForegroundColorSpan(color), start, end, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
    }
    if (strikethrough) {
      spannable.setSpan(StrikethroughSpan(), start, end, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
    }
  }

  /**
   * Drops only the decoration spans this file and `ListItemRenderer` add for a
   * checked item. Both are matched by exact class: the package's own
   * `~~strikethrough~~` span subclasses the framework one, and a subclass here
   * belongs to the markdown itself, not to the checked state. Removing the
   * color span is enough to restore the item's text color — [BaseListSpan]
   * paints it from the list style once nothing overrides it.
   */
  private fun removeCheckedSpans(
    spannable: Spannable,
    start: Int,
    end: Int,
  ) {
    spannable
      .getSpans(start, end, StrikethroughSpan::class.java)
      .filter { it.javaClass == StrikethroughSpan::class.java }
      .forEach { spannable.removeSpan(it) }

    spannable
      .getSpans(start, end, ForegroundColorSpan::class.java)
      .filter { it.javaClass == ForegroundColorSpan::class.java }
      .forEach { spannable.removeSpan(it) }
  }
}
