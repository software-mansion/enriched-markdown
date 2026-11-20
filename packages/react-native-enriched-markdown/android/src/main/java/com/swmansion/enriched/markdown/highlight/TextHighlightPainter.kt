package com.swmansion.enriched.markdown.highlight

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.text.Layout
import android.text.Spanned
import android.text.style.LineBackgroundSpan
import android.widget.TextView
import com.swmansion.enriched.markdown.spans.ListItemSpacingSpan
import com.swmansion.enriched.markdown.spans.MarginBottomSpan

/**
 * Draws a text view's highlights behind its glyphs. The view calls [draw] at the
 * start of `onDraw`, before the text and the selection, so neither the text nor
 * what is copied from it changes. Where the text paints its own background (code,
 * quotes, marks), that background would hide the highlight, so [drawOverBackgrounds]
 * paints those parts again after the text.
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
  private val rect = RectF()

  fun draw(canvas: Canvas) {
    if (highlights.isEmpty()) return
    val layout = view.layout ?: return
    canvas.save()
    canvas.translate(view.totalPaddingLeft.toFloat(), view.totalPaddingTop.toFloat())
    highlights.forEach { fill(canvas, layout, it) }
    canvas.restore()
  }

  fun drawOverBackgrounds(canvas: Canvas) {
    if (highlights.isEmpty()) return
    val layout = view.layout ?: return
    val text = layout.text as? Spanned ?: return
    canvas.save()
    canvas.translate(view.totalPaddingLeft.toFloat(), view.totalPaddingTop.toFloat())
    for (highlight in highlights) {
      for (span in text.getSpans(highlight.start, highlight.end, LineBackgroundSpan::class.java)) {
        val start = maxOf(highlight.start, text.getSpanStart(span))
        val end = minOf(highlight.end, text.getSpanEnd(span))
        if (end > start) fill(canvas, layout, highlight.copy(start = start, end = end))
      }
    }
    canvas.restore()
  }

  private fun fill(
    canvas: Canvas,
    layout: Layout,
    highlight: TextHighlight,
  ) {
    paint.color = highlight.color
    forEachLineRect(layout, highlight) { box ->
      val radius = minOf(highlight.borderRadius, box.width() / 2, box.height() / 2)
      canvas.drawRoundRect(box, radius, radius, paint)
    }
  }

  /** The union of [highlight]'s line boxes in the view's coordinates, or null when none is laid out. */
  fun bounds(highlight: TextHighlight): RectF? {
    val layout = view.layout ?: return null
    var union: RectF? = null
    forEachLineRect(layout, highlight) { box ->
      val current = union
      if (current == null) union = RectF(box) else current.union(box)
    }
    union?.offset(view.totalPaddingLeft.toFloat(), view.totalPaddingTop.toFloat())
    return union
  }

  // Each line's box, tight to its glyphs: a paragraph's spacing below stays out.
  private inline fun forEachLineRect(
    layout: Layout,
    highlight: TextHighlight,
    block: (RectF) -> Unit,
  ) {
    val text = layout.text
    val start = highlight.start.coerceIn(0, text.length)
    val end = highlight.end.coerceIn(0, text.length)
    if (end <= start) return
    val firstLine = layout.getLineForOffset(start)
    val lastLine = layout.getLineForOffset(maxOf(start, end - 1))
    for (line in firstLine..lastLine) {
      val lineStart = maxOf(start, layout.getLineStart(line))
      var lineEnd = minOf(end, layout.getLineEnd(line))
      while (lineEnd > lineStart && text[lineEnd - 1] == '\n') lineEnd--
      if (lineEnd <= lineStart) continue
      path.reset()
      layout.getSelectionPath(lineStart, lineEnd, path)
      path.computeBounds(rect, true)
      if (rect.width() <= 0f) continue
      rect.top = layout.getLineTop(line).toFloat()
      rect.bottom = lineBottomWithoutSpacing(layout, line).toFloat()
      rect.inset(-highlight.padding, -highlight.padding)
      block(rect)
    }
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
