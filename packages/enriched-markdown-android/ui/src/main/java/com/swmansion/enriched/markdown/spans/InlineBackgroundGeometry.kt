package com.swmansion.enriched.markdown.spans

import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.text.Layout
import android.text.Spanned
import android.text.TextPaint
import android.text.style.LeadingMarginSpan
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
  private val drawnSide = Path()
  private val selectionBounds = RectF()

  fun registerTextView(view: TextView) {
    if (textViewRef?.get() !== view) textViewRef = WeakReference(view)
  }

  /**
   * The x ranges of [spanStart]..[spanEnd] on [line], left to right. Mixed-direction text can
   * split them into several. Without a registered layout, the line is measured from its start.
   */
  fun ranges(
    text: Spanned,
    line: Int,
    lineStart: Int,
    lineEnd: Int,
    spanStart: Int,
    spanEnd: Int,
    left: Int,
    right: Int,
    paint: Paint,
  ): List<HorizontalRange> {
    val layout = textViewRef?.get()?.layout?.takeIf { it.text === text }
    if (layout != null) return layout.glyphRanges(line, spanStart, spanEnd)

    val startX =
      if (spanStart >= lineStart) {
        left + measuredOffset(text, lineStart, spanStart, paint)
      } else {
        left.toFloat() + leadingMarginAt(text, lineStart)
      }
    val endX = if (spanEnd <= lineEnd) left + measuredOffset(text, lineStart, spanEnd, paint) else right.toFloat()
    return listOf(HorizontalRange(min(startX, endX), max(startX, endX)))
  }

  /**
   * Read from the layout's selection, which knows each glyph's edges. Caret positions don't where
   * the direction changes. Each single-direction run is selected on its own, since runs of
   * opposite directions may be drawn apart.
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
      selectedRange(line, runStart, runEnd)?.let(ranges::add)
      runStart = runEnd
    }
    return mergeTouching(ranges)
  }

  private fun Layout.selectedRange(
    line: Int,
    start: Int,
    end: Int,
  ): HorizontalRange? {
    getSelectionPath(start, end, selection)
    // A mid-word line break's end offset also starts the next line, so the selection runs on to
    // the view edge. Cut it at the line's trailing edge.
    if (end == getLineEnd(line) && line < lineCount - 1) {
      val top = getLineTop(line).toFloat()
      val bottom = getLineBottom(line).toFloat()
      drawnSide.reset()
      if (getParagraphDirection(line) == Layout.DIR_RIGHT_TO_LEFT) {
        drawnSide.addRect(getLineLeft(line), top, width.toFloat(), bottom, Path.Direction.CW)
      } else {
        drawnSide.addRect(0f, top, getLineRight(line), bottom, Path.Direction.CW)
      }
      selection.op(drawnSide, Path.Op.INTERSECT)
    }
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

  /** The x of [index] from the line's left edge. Exact only for start-aligned LTR text. */
  private fun measuredOffset(
    text: Spanned,
    lineStart: Int,
    index: Int,
    paint: Paint,
  ): Float {
    if (index <= lineStart) return leadingMarginAt(text, lineStart).toFloat()
    val textPaint = paint as? TextPaint ?: TextPaint(paint)
    // getDesiredWidth already adds the paragraph's leading margin.
    return Layout.getDesiredWidth(text, lineStart, index, textPaint)
  }

  private fun leadingMarginAt(
    text: Spanned,
    lineStart: Int,
  ): Int {
    if (lineStart >= text.length) return 0
    val spans = text.getSpans(lineStart, lineStart + 1, LeadingMarginSpan::class.java)
    var margin = 0
    for (span in spans) {
      margin += span.getLeadingMargin(false)
    }
    return margin
  }

  private companion object {
    // Pixels between two ranges that still count as touching.
    const val TOUCHING = 0.5f
  }
}
