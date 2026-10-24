package com.swmansion.enriched.markdown.spans

import android.graphics.Path
import android.graphics.RectF
import android.text.Layout
import android.text.Spanned
import android.widget.TextView
import java.lang.ref.WeakReference
import kotlin.math.max
import kotlin.math.min

/** An x range an inline background covers on one line. */
internal data class HorizontalRange(
  val left: Float,
  val right: Float,
)

/** Places an inline background (code, highlight) on each line of its span. */
internal class InlineBackgroundGeometry {
  // Weak, so a rendered text that outlives its view does not keep the view alive.
  private var textViewRef: WeakReference<TextView>? = null

  // Reused on every draw.
  private val selection = Path()
  private val selectionBounds = RectF()

  fun registerTextView(view: TextView) {
    if (textViewRef?.get() !== view) textViewRef = WeakReference(view)
  }

  /**
   * The x ranges of [spanStart]..[spanEnd] on [line], left to right. Mixed-direction text can
   * split them into several. Empty until a view showing [text] registers.
   */
  fun ranges(
    text: Spanned,
    line: Int,
    spanStart: Int,
    spanEnd: Int,
  ): List<HorizontalRange> {
    val layout = textViewRef?.get()?.layout?.takeIf { it.text === text } ?: return emptyList()
    return layout.glyphRanges(line, spanStart, spanEnd)
  }

  /**
   * Read from the layout's selection rather than caret positions, which can point at the wrong
   * glyph where the text direction changes. Each single-direction run is selected on its own,
   * since runs of opposite directions may be drawn apart.
   */
  private fun Layout.glyphRanges(
    line: Int,
    spanStart: Int,
    spanEnd: Int,
  ): List<HorizontalRange> {
    val start = max(spanStart, getLineStart(line))
    val end = min(spanEnd, glyphsEnd(line))
    val ranges = ArrayList<HorizontalRange>(1)
    var runStart = start
    while (runStart < end) {
      val isRtl = isRtlCharAt(runStart)
      var runEnd = runStart + 1
      while (runEnd < end && isRtlCharAt(runEnd) == isRtl) runEnd++
      selectedRange(runStart, runEnd)?.let(ranges::add)
      runStart = runEnd
    }
    return mergeTouching(ranges)
  }

  private fun Layout.selectedRange(
    start: Int,
    end: Int,
  ): HorizontalRange? {
    getSelectionPath(start, end, selection)
    if (selection.isEmpty) return null
    selection.computeBounds(selectionBounds, true)
    return HorizontalRange(selectionBounds.left, selectionBounds.right)
  }

  /** Where [line]'s glyphs end, before trailing whitespace. */
  private fun Layout.glyphsEnd(line: Int): Int {
    val lineStart = getLineStart(line)
    var glyphsEnd = getLineEnd(line)
    while (glyphsEnd > lineStart && text[glyphsEnd - 1].isWhitespace()) glyphsEnd--
    return glyphsEnd
  }

  /** Sorts [ranges] and joins those that touch, as adjacent runs of opposite directions do. */
  private fun mergeTouching(ranges: List<HorizontalRange>): List<HorizontalRange> {
    if (ranges.size < 2) return ranges
    val merged = ArrayList<HorizontalRange>(ranges.size)
    for (range in ranges.sortedBy { it.left }) {
      val previous = merged.lastOrNull()
      if (previous != null && range.left <= previous.right + TOUCHING) {
        merged[merged.lastIndex] = HorizontalRange(previous.left, max(previous.right, range.right))
      } else {
        merged.add(range)
      }
    }
    return merged
  }

  private companion object {
    // Pixels between two ranges that still count as touching.
    const val TOUCHING = 0.5f
  }
}
