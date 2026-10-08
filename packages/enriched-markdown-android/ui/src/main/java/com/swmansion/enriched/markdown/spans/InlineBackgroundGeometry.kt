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

/**
 * Where an inline background (code, highlight) goes horizontally on each line its span covers. A
 * span owns one and passes on the view it registers with, whose layout places the background
 * exactly for any alignment and direction.
 */
internal class InlineBackgroundGeometry {
  // Weak, so a rendered text that outlives its view does not keep the view alive.
  private var textViewRef: WeakReference<TextView>? = null

  // Reused on every draw.
  private val selection = Path()
  private val drawnSide = Path()
  private val selectionBounds = RectF()
  private var lefts = FloatArray(2)
  private var rights = FloatArray(2)

  /** How many x ranges the last [findRanges] found. */
  var rangeCount = 0
    private set

  /** The left of the [index]th range the last [findRanges] found, counting from the left. */
  fun rangeLeft(index: Int): Float = lefts[index]

  /** The right of the [index]th range the last [findRanges] found, counting from the left. */
  fun rangeRight(index: Int): Float = rights[index]

  fun registerTextView(view: TextView) {
    if (textViewRef?.get() !== view) textViewRef = WeakReference(view)
  }

  /**
   * Finds the x ranges of [spanStart]..[spanEnd] on [line], which holds [lineStart]..[lineEnd] of
   * [text] and is drawn between [left] and [right], and leaves them in [rangeCount], [rangeLeft]
   * and [rangeRight]. There is usually one, but where the line mixes directions the span's glyphs
   * can lie on both sides of other text, and each stretch gets its own range. Only a layout knows
   * where the glyphs are for every alignment and direction; without one, there is a single range
   * measured from the line's start, which runs to the view edges on a line the span continues
   * onto or past.
   */
  fun findRanges(
    text: Spanned,
    line: Int,
    lineStart: Int,
    lineEnd: Int,
    spanStart: Int,
    spanEnd: Int,
    left: Int,
    right: Int,
    paint: Paint,
  ) {
    rangeCount = 0
    // The layout drawing this line, when the view showing the text registered with this span. Its
    // x positions are in the same frame as left and right, which the layout draws from.
    val layout = textViewRef?.get()?.layout?.takeIf { it.text === text }
    if (layout != null) {
      layout.findGlyphRanges(line, spanStart, spanEnd)
      return
    }
    val startX =
      if (spanStart >= lineStart) {
        left + measuredOffset(text, lineStart, spanStart, paint)
      } else {
        left.toFloat() + leadingMarginAt(text, lineStart)
      }
    val endX = if (spanEnd <= lineEnd) left + measuredOffset(text, lineStart, spanEnd, paint) else right.toFloat()
    addRange(min(startX, endX), max(startX, endX))
  }

  /**
   * Adds the ranges of the glyphs [spanStart]..[spanEnd] draws on [line], leaving out whitespace
   * the line ends with, which is not drawn. They are read from the layout's selection, which
   * places each glyph by its own edges. A caret position does not: where the text changes
   * direction, it sits at the edge of whichever run the paragraph's direction favours, which may be
   * the far end of the other run.
   */
  private fun Layout.findGlyphRanges(
    line: Int,
    spanStart: Int,
    spanEnd: Int,
  ) {
    val start = max(spanStart, getLineStart(line))
    val end = min(spanEnd, glyphsEnd(line))
    // The glyphs of one direction are drawn side by side, but a run of the other direction may be
    // drawn apart from them, so each run is selected on its own.
    var runStart = start
    while (runStart < end) {
      val isRtl = isRtlCharAt(runStart)
      var runEnd = runStart + 1
      while (runEnd < end && isRtlCharAt(runEnd) == isRtl) runEnd++
      addSelectedRange(line, runStart, runEnd)
      runStart = runEnd
    }
  }

  /** Adds the range of [start]..[end] on [line], which is a run of a single direction. */
  private fun Layout.addSelectedRange(
    line: Int,
    start: Int,
    end: Int,
  ) {
    getSelectionPath(start, end, selection)
    // An end where a line breaks mid-word also starts the next line, so the selection carries on
    // past this line's glyphs to the view edge. That part lies beyond the line's trailing edge.
    if (end == getLineEnd(line) && line < lineCount - 1) {
      drawnSide.reset()
      if (getParagraphDirection(line) == Layout.DIR_RIGHT_TO_LEFT) {
        drawnSide.addRect(getLineLeft(line), getLineTop(line).toFloat(), width.toFloat(), getLineBottom(line).toFloat(), Path.Direction.CW)
      } else {
        drawnSide.addRect(0f, getLineTop(line).toFloat(), getLineRight(line), getLineBottom(line).toFloat(), Path.Direction.CW)
      }
      selection.op(drawnSide, Path.Op.INTERSECT)
    }
    if (selection.isEmpty) return
    selection.computeBounds(selectionBounds, true)
    addRange(selectionBounds.left, selectionBounds.right)
  }

  /** The end of [line]'s text, leaving out the whitespace and line break it ends with. */
  private fun Layout.glyphsEnd(line: Int): Int {
    val lineStart = getLineStart(line)
    var glyphsEnd = getLineEnd(line)
    while (glyphsEnd > lineStart && text[glyphsEnd - 1].isWhitespace()) glyphsEnd--
    return glyphsEnd
  }

  /**
   * Adds [left]..[right] to the ranges, kept in order from the left. A range touching others,
   * as runs of opposite directions drawn side by side do, is merged with them.
   */
  private fun addRange(
    left: Float,
    right: Float,
  ) {
    var mergedLeft = left
    var mergedRight = right
    var kept = 0
    for (i in 0 until rangeCount) {
      if (lefts[i] <= mergedRight + TOUCHING && rights[i] >= mergedLeft - TOUCHING) {
        mergedLeft = min(mergedLeft, lefts[i])
        mergedRight = max(mergedRight, rights[i])
      } else {
        lefts[kept] = lefts[i]
        rights[kept] = rights[i]
        kept++
      }
    }
    if (kept == lefts.size) {
      lefts = lefts.copyOf(kept * 2)
      rights = rights.copyOf(kept * 2)
    }
    var at = kept
    while (at > 0 && lefts[at - 1] > mergedLeft) {
      lefts[at] = lefts[at - 1]
      rights[at] = rights[at - 1]
      at--
    }
    lefts[at] = mergedLeft
    rights[at] = mergedRight
    rangeCount = kept + 1
  }

  /**
   * The x of [index] relative to the line's left edge, for text drawn by a view that did not
   * register with the span. It measures the line from its start, so it is exact only for
   * left-to-right text aligned to the start; a registered view's layout is exact for any
   * alignment and direction.
   */
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
    // How far apart, in pixels, two ranges may be and still be drawn as one.
    const val TOUCHING = 0.5f
  }
}
