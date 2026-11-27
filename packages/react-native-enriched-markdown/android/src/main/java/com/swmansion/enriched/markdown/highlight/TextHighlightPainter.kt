package com.swmansion.enriched.markdown.highlight

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PathMeasure
import android.graphics.RectF
import android.text.Layout
import android.text.Spannable
import android.text.Spanned
import android.text.style.LineBackgroundSpan
import android.widget.TextView
import com.swmansion.enriched.markdown.spans.ListItemSpacingSpan
import com.swmansion.enriched.markdown.spans.MarginBottomSpan

/**
 * Draws a text view's highlights behind its glyphs, so neither the text nor what is
 * copied from it changes. [attach] adds a line background span after the text's own,
 * so the highlight lands on top of code, quote and mark backgrounds and under the
 * glyphs and the selection. Text that is not [Spannable] cannot take the span; for it
 * the view calls [draw] before the text, where those backgrounds can hide it.
 */
class TextHighlightPainter(
  private val view: TextView,
) {
  var highlights: List<TextHighlight> = emptyList()
    set(value) {
      if (field == value) return
      field = value
      view.invalidate()
    }

  private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
  private val path = Path()
  private val run = Path()
  private val measure = PathMeasure()
  private val rect = RectF()
  private val runs = ArrayList<RectF>()
  private var runCount = 0
  private val span = BackgroundSpan()

  /** Adds the span to the view's current text. Call after each `setText`. */
  fun attach() {
    val text = view.text as? Spannable ?: return
    text.setSpan(span, 0, text.length, Spanned.SPAN_INCLUSIVE_INCLUSIVE)
  }

  /** Whether the span draws the highlights; when not, call [draw] before the text. */
  val isAttached: Boolean
    get() = (view.text as? Spanned)?.getSpanStart(span)?.let { it >= 0 } == true

  fun draw(canvas: Canvas) {
    if (highlights.isEmpty()) return
    val layout = view.layout ?: return
    canvas.save()
    canvas.translate(view.totalPaddingLeft.toFloat(), view.totalPaddingTop.toFloat())
    for (line in 0 until layout.lineCount) fillLine(canvas, layout, line)
    canvas.restore()
  }

  private fun fillLine(
    canvas: Canvas,
    layout: Layout,
    line: Int,
  ) {
    for (highlight in highlights) {
      paint.color = highlight.color
      forEachRunRect(layout, highlight, line) { box ->
        val radius = minOf(highlight.borderRadius, box.width() / 2, box.height() / 2)
        canvas.drawRoundRect(box, radius, radius, paint)
      }
    }
  }

  // Layout draws line backgrounds in the order their spans were added, then the
  // selection and the glyphs, with the canvas already at the layout's origin.
  private inner class BackgroundSpan : LineBackgroundSpan {
    override fun drawBackground(
      canvas: Canvas,
      p: Paint,
      left: Int,
      right: Int,
      top: Int,
      baseline: Int,
      bottom: Int,
      text: CharSequence,
      start: Int,
      end: Int,
      lineNumber: Int,
    ) {
      if (highlights.isEmpty()) return
      val layout = view.layout ?: return
      fillLine(canvas, layout, lineNumber)
    }
  }

  /** The union of [highlight]'s boxes in the view's coordinates, or null when none is laid out. */
  fun bounds(highlight: TextHighlight): RectF? {
    val layout = view.layout ?: return null
    val text = layout.text
    val start = highlight.start.coerceIn(0, text.length)
    val end = highlight.end.coerceIn(0, text.length)
    if (end <= start) return null
    var union: RectF? = null
    for (line in layout.getLineForOffset(start)..layout.getLineForOffset(end - 1)) {
      forEachRunRect(layout, highlight, line) { box ->
        val current = union
        if (current == null) union = RectF(box) else current.union(box)
      }
    }
    union?.offset(view.totalPaddingLeft.toFloat(), view.totalPaddingTop.toFloat())
    return union
  }

  // The highlight's boxes on one line, tight to its glyphs: a paragraph's spacing below
  // stays out. The selection path holds one rect per directional run, and each gets its
  // own box, so in mixed-direction text the unselected glyphs between runs stay clear.
  private inline fun forEachRunRect(
    layout: Layout,
    highlight: TextHighlight,
    line: Int,
    block: (RectF) -> Unit,
  ) {
    val text = layout.text
    val lineStart = maxOf(highlight.start, layout.getLineStart(line)).coerceIn(0, text.length)
    var lineEnd = minOf(highlight.end, layout.getLineEnd(line)).coerceIn(0, text.length)
    while (lineEnd > lineStart && text[lineEnd - 1] == '\n') lineEnd--
    if (lineEnd <= lineStart) return
    val top = layout.getLineTop(line).toFloat()
    val bottom = lineBottomWithoutSpacing(layout, line).toFloat()
    path.reset()
    layout.getSelectionPath(lineStart, lineEnd, path)
    collectRuns()
    for (i in 0 until runCount) {
      rect.set(runs[i].left, top, runs[i].right, bottom)
      rect.inset(-highlight.padding, -highlight.padding)
      block(rect)
    }
  }

  // The horizontal extent of each contour in `path`, left to right. Contours that touch,
  // such as a line's trailing space, join the run beside them.
  private fun collectRuns() {
    runCount = 0
    measure.setPath(path, false)
    do {
      run.reset()
      if (!measure.getSegment(0f, measure.length, run, true)) continue
      run.computeBounds(rect, true)
      if (rect.width() <= 0f) continue
      if (runCount == runs.size) runs += RectF()
      runs[runCount++].set(rect)
    } while (measure.nextContour())
    if (runCount < 2) return
    runs.subList(0, runCount).sortBy { it.left }
    var merged = 0
    for (i in 1 until runCount) {
      val last = runs[merged]
      val next = runs[i]
      if (next.left <= last.right + 0.5f) {
        last.right = maxOf(last.right, next.right)
      } else {
        merged++
        if (merged != i) runs[merged].set(next)
      }
    }
    runCount = merged + 1
  }

  private fun lineBottomWithoutSpacing(
    layout: Layout,
    line: Int,
  ): Int {
    val bottom = layout.getLineBottom(line)
    val text = layout.text as? Spanned ?: return bottom
    val lineStart = layout.getLineStart(line)
    val lineEnd = layout.getLineEnd(line)
    if (lineEnd - lineStart < 2 || text[lineEnd - 1] != '\n') return bottom
    var spacing = 0
    if (hasContentAfter(text, lineEnd)) {
      text.getSpans(lineEnd - 1, lineEnd, MarginBottomSpan::class.java).forEach { spacing += it.marginBottom.toInt() }
    }
    text.getSpans(lineEnd - 1, lineEnd, ListItemSpacingSpan::class.java).forEach {
      if (text.getSpanEnd(it) == lineEnd) spacing += it.spacing.toInt()
    }
    return maxOf(layout.getLineBaseline(line), bottom - spacing)
  }

  // Mirrors MarginBottomSpan: spacing is added only before more content.
  private fun hasContentAfter(
    text: CharSequence,
    pos: Int,
  ): Boolean {
    if (pos >= text.length) return false
    if (text[pos] == '\n') return pos + 1 < text.length && text[pos + 1] != '\n'
    return true
  }
}
