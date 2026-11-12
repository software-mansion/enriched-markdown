package com.swmansion.enriched.markdown.spans

import android.graphics.Canvas
import android.graphics.Rect
import android.text.Layout
import android.text.Spanned
import android.widget.TextView

/**
 * The text's background pass, under its glyphs, as iOS draws it in its layout manager: blockquote
 * fills first, then highlight and inline code backgrounds on top of them. Where a span starts and
 * ends on a line is the layout's own ([Layout.getPrimaryHorizontal]), so margins, alignment,
 * right-to-left text and justification place the background where the glyphs are. Only the lines
 * the canvas shows are drawn, and the positions found on a line are kept until its text changes
 * ([invalidateFrom]), the layout is replaced or resized, or an inline image or link pill changes
 * width ([noteReflow]), so a fade that redraws the text every frame doesn't measure it again.
 * One per text view; main thread only.
 */
internal class TextBackgroundDrawer {
  companion object {
    private val clip = Rect()

    // Bumped when an inline image or link pill changes width in place: what follows it on its
    // line moves while the line's text stays the same.
    private var reflows = 0

    fun noteReflow() {
      reflows++
    }
  }

  // The positions found on a line while it runs from [start] to [end], by offset from [start].
  private class LinePositions(
    val start: Int,
    val end: Int,
  ) {
    val xs = FloatArray(end - start).apply { fill(Float.NaN) }
    var textEnd = Float.NaN
  }

  private val lines = HashMap<Int, LinePositions>()
  private var cachedLayout: Layout? = null
  private var cachedWidth = -1
  private var cachedReflows = -1

  /** The text changed from [offset] on: positions on lines that reach it are found again. */
  fun invalidateFrom(offset: Int) {
    lines.values.removeAll { it.end >= offset }
  }

  /** Draws under [view]'s text, clipped as [TextView.onDraw] clips the text. */
  fun draw(
    canvas: Canvas,
    view: TextView,
  ) {
    val layout = view.layout ?: return
    val top = view.extendedPaddingTop
    val bottom = view.extendedPaddingBottom
    val maxScrollY = layout.height - (view.height - top - bottom)
    canvas.save()
    canvas.clipRect(
      view.compoundPaddingLeft + view.scrollX,
      if (view.scrollY == 0) 0 else top + view.scrollY,
      view.width - view.compoundPaddingRight + view.scrollX,
      view.height + view.scrollY - (if (view.scrollY == maxScrollY) 0 else bottom),
    )
    draw(canvas, layout, layout.text, view.totalPaddingLeft.toFloat(), view.totalPaddingTop.toFloat())
    canvas.restore()
  }

  /** Draws under [layout]'s text, which the view draws at ([left], [top]) of [canvas]. */
  fun draw(
    canvas: Canvas,
    layout: Layout?,
    text: CharSequence?,
    left: Float,
    top: Float,
  ) {
    if (layout == null || text !is Spanned || layout.lineCount == 0 || !canvas.getClipBounds(clip)) return
    if (layout !== cachedLayout || layout.width != cachedWidth || reflows != cachedReflows) {
      lines.clear()
      cachedLayout = layout
      cachedWidth = layout.width
      cachedReflows = reflows
    }
    val first = layout.getLineForVertical((clip.top - top).toInt().coerceAtLeast(0))
    val last = layout.getLineForVertical((clip.bottom - 1 - top).toInt().coerceAtLeast(0))
    val start = layout.getLineStart(first)
    val end = layout.getLineEnd(last)
    val quotes = text.getSpans(start, end, BlockquoteSpan::class.java)
    val highlights = text.getSpans(start, end, HighlightSpan::class.java)
    val code = text.getSpans(start, end, CodeBackgroundSpan::class.java)
    if (quotes.isEmpty() && highlights.isEmpty() && code.isEmpty()) return

    canvas.save()
    canvas.translate(left, top)
    // Called as the layout would call a LineBackgroundSpan: the line box across the full width.
    for (span in quotes) {
      forEachLine(layout, text, span, first, last) { line, lineStart, lineEnd, _, _ ->
        span.drawBackground(canvas, 0, layout.width, layout.getLineTop(line), layout.getLineTop(line + 1), text, lineStart, lineEnd)
      }
    }
    for (span in highlights) {
      forEachLine(layout, text, span, first, last) { line, lineStart, lineEnd, spanStart, spanEnd ->
        span.drawLine(canvas, this, layout, line, lineStart, lineEnd, spanStart, spanEnd)
      }
    }
    for (span in code) {
      forEachLine(layout, text, span, first, last) { line, lineStart, lineEnd, spanStart, spanEnd ->
        span.drawLine(canvas, this, layout, line, lineStart, lineEnd, spanStart, spanEnd, text)
      }
    }
    canvas.restore()
  }

  // The shown lines [span] is on, from [first] to [last].
  private inline fun forEachLine(
    layout: Layout,
    text: Spanned,
    span: Any,
    first: Int,
    last: Int,
    draw: (line: Int, lineStart: Int, lineEnd: Int, spanStart: Int, spanEnd: Int) -> Unit,
  ) {
    val spanStart = text.getSpanStart(span)
    val spanEnd = text.getSpanEnd(span)
    if (spanStart !in 0 until spanEnd) return
    val from = maxOf(first, layout.getLineForOffset(spanStart))
    val to = minOf(last, layout.getLineForOffset(spanEnd - 1))
    for (line in from..to) draw(line, layout.getLineStart(line), layout.getLineEnd(line), spanStart, spanEnd)
  }

  /**
   * The x of [offset] on [line], which runs from [lineStart] to [lineEnd]: before the start, the
   * start's; at or past the end (where a wrapped line's offset belongs to the next one), where the
   * line's glyphs end.
   */
  fun x(
    layout: Layout,
    line: Int,
    lineStart: Int,
    lineEnd: Int,
    offset: Int,
  ): Float {
    if (lineStart >= lineEnd) return layout.getPrimaryHorizontal(lineStart)
    val positions = positionsOn(line, lineStart, lineEnd)
    if (offset >= lineEnd) {
      if (positions.textEnd.isNaN()) positions.textEnd = textEnd(layout, line, x(layout, line, lineStart, lineEnd, lineStart))
      return positions.textEnd
    }
    val at = maxOf(offset, lineStart)
    val kept = positions.xs[at - lineStart]
    if (!kept.isNaN()) return kept
    return layout.getPrimaryHorizontal(at).also { positions.xs[at - lineStart] = it }
  }

  // The line's glyphs run from [start] for its extent less the leading margin. getLineLeft and
  // getLineRight count the margin twice before Android 10.
  private fun textEnd(
    layout: Layout,
    line: Int,
    start: Float,
  ): Float {
    val rightToLeft = layout.getParagraphDirection(line) == Layout.DIR_RIGHT_TO_LEFT
    val margin = if (rightToLeft) layout.width - layout.getParagraphRight(line) else layout.getParagraphLeft(line)
    val extent = layout.getLineMax(line) - margin
    return if (rightToLeft) start - extent else start + extent
  }

  private fun positionsOn(
    line: Int,
    lineStart: Int,
    lineEnd: Int,
  ): LinePositions {
    val kept = lines[line]
    if (kept != null && kept.start == lineStart && kept.end == lineEnd) return kept
    return LinePositions(lineStart, lineEnd).also { lines[line] = it }
  }
}
