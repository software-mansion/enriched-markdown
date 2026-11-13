package com.swmansion.enriched.markdown.spans

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.text.Layout
import android.text.Spanned
import com.swmansion.enriched.markdown.spoiler.isConcealedBySpoiler
import com.swmansion.enriched.markdown.styles.StyleConfig
import kotlin.math.max
import kotlin.math.min

/** Marks inline code; [TextBackgroundDrawer] draws its background from the text's layout. */
class CodeBackgroundSpan(
  private val styleConfig: StyleConfig,
) {
  companion object {
    private const val CORNER_RADIUS = 6.0f
    private const val BORDER_WIDTH = 1.0f
    private const val R = CORNER_RADIUS
    private val ROUND_BOTH = floatArrayOf(R, R, R, R, R, R, R, R)
    private val ROUND_LEFT = floatArrayOf(R, R, 0f, 0f, 0f, 0f, R, R)
    private val ROUND_RIGHT = floatArrayOf(0f, 0f, R, R, R, R, 0f, 0f)
    private val ROUND_NONE = FloatArray(8)

    private val sharedBackgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val sharedBorderPaint =
      Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = BORDER_WIDTH
        strokeJoin = Paint.Join.ROUND
        strokeCap = Paint.Cap.ROUND
      }
  }

  // Reusable drawing objects per instance
  private val rect = RectF()
  private val path = Path()

  /** Draws this span's background, from [spanStart] to [spanEnd], on [line] of [layout], from [lineStart] to [lineEnd]. */
  internal fun drawLine(
    canvas: Canvas,
    drawer: TextBackgroundDrawer,
    layout: Layout,
    line: Int,
    lineStart: Int,
    lineEnd: Int,
    spanStart: Int,
    spanEnd: Int,
    text: Spanned,
  ) {
    if (spanEnd <= lineStart || spanStart >= lineEnd) return

    // The spoiler overlay only covers the text's glyph box, so a background drawn to the line's bounds
    // would outline the hidden code around it.
    if (text.isConcealedBySpoiler(maxOf(spanStart, lineStart), minOf(spanEnd, lineEnd))) return

    val rightToLeft = layout.getParagraphDirection(line) == Layout.DIR_RIGHT_TO_LEFT
    val top = layout.getLineTop(line)
    val bottom = adjustBottomForMargin(text, lineEnd, layout.getLineTop(line + 1))

    // Keep CodeSpan and this background span intact for semantic extraction. Draw only
    // portions outside replacement pills, including code surrounding a partially covered run.
    fun drawUncoveredRange(
      rangeStart: Int,
      rangeEnd: Int,
    ) {
      if (max(rangeStart, lineStart) >= min(rangeEnd, lineEnd)) return
      val isFirst = rangeStart >= lineStart
      val isLast = rangeEnd <= lineEnd
      val startX = drawer.x(layout, line, lineStart, lineEnd, if (isFirst) rangeStart else lineStart)
      val endX = drawer.x(layout, line, lineStart, lineEnd, if (isLast) rangeEnd else lineEnd)
      rect.set(min(startX, endX), top.toFloat(), max(startX, endX), bottom.toFloat())

      val codeStyle = styleConfig.codeStyle
      sharedBackgroundPaint.color = codeStyle.backgroundColor
      sharedBorderPaint.color = codeStyle.borderColor
      // A right-to-left line starts on the right, so the span's first fragment is closed there.
      if (rightToLeft) drawShapes(canvas, isLast, isFirst) else drawShapes(canvas, isFirst, isLast)
    }

    // Only query for pills if the style can produce any.
    val pills = if (styleConfig.hasLinkPills) text.getSpans(spanStart, spanEnd, LinkPillSpan::class.java) else emptyArray()
    if (pills.isEmpty()) {
      drawUncoveredRange(spanStart, spanEnd)
      return
    }
    if (pills.size > 1) pills.sortBy { text.getSpanStart(it) }
    var cursor = spanStart
    for (pill in pills) {
      val coveredStart = max(spanStart, text.getSpanStart(pill))
      val coveredEnd = min(spanEnd, text.getSpanEnd(pill))
      if (coveredStart >= coveredEnd) continue
      if (cursor < coveredStart) drawUncoveredRange(cursor, coveredStart)
      cursor = max(cursor, coveredEnd)
    }
    drawUncoveredRange(cursor, spanEnd)
  }

  // Rounds and closes the [closedLeft] and [closedRight] sides of [rect].
  private fun drawShapes(
    canvas: Canvas,
    closedLeft: Boolean,
    closedRight: Boolean,
  ) {
    path.reset()
    path.addRoundRect(rect, radii(closedLeft, closedRight), Path.Direction.CW)
    canvas.drawPath(path, sharedBackgroundPaint)

    if (closedLeft && closedRight) {
      canvas.drawPath(path, sharedBorderPaint)
    } else {
      drawOpenBorders(canvas, closedLeft, closedRight)
    }
  }

  private fun drawOpenBorders(
    canvas: Canvas,
    closedLeft: Boolean,
    closedRight: Boolean,
  ) {
    val r = CORNER_RADIUS
    path.reset()

    if (closedLeft) {
      path.moveTo(rect.right, rect.top)
      path.lineTo(rect.left + r, rect.top)
      path.quadTo(rect.left, rect.top, rect.left, rect.top + r)
      path.lineTo(rect.left, rect.bottom - r)
      path.quadTo(rect.left, rect.bottom, rect.left + r, rect.bottom)
      path.lineTo(rect.right, rect.bottom)
    } else if (closedRight) {
      path.moveTo(rect.left, rect.top)
      path.lineTo(rect.right - r, rect.top)
      path.quadTo(rect.right, rect.top, rect.right, rect.top + r)
      path.lineTo(rect.right, rect.bottom - r)
      path.quadTo(rect.right, rect.bottom, rect.right - r, rect.bottom)
      path.lineTo(rect.left, rect.bottom)
    } else {
      path.moveTo(rect.left, rect.top)
      path.lineTo(rect.right, rect.top)
      path.moveTo(rect.left, rect.bottom)
      path.lineTo(rect.right, rect.bottom)
    }
    canvas.drawPath(path, sharedBorderPaint)
  }

  private fun radii(
    closedLeft: Boolean,
    closedRight: Boolean,
  ) = when {
    closedLeft && closedRight -> ROUND_BOTH
    closedLeft -> ROUND_LEFT
    closedRight -> ROUND_RIGHT
    else -> ROUND_NONE
  }

  private fun adjustBottomForMargin(
    text: Spanned,
    lineEnd: Int,
    bottom: Int,
  ): Int {
    if (lineEnd <= 0 || lineEnd > text.length || text[lineEnd - 1] != '\n') return bottom
    val marginSpans = text.getSpans(lineEnd - 1, lineEnd, MarginBottomSpan::class.java)
    var adjusted = bottom
    for (span in marginSpans) {
      if (text.getSpanEnd(span) == lineEnd) adjusted -= span.marginBottom.toInt()
    }
    return adjusted
  }
}
