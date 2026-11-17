package com.swmansion.enriched.markdown.spans

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.text.Layout
import android.text.TextPaint
import android.text.style.CharacterStyle
import com.swmansion.enriched.markdown.renderer.BlockStyle
import com.swmansion.enriched.markdown.renderer.SpanStyleCache
import kotlin.math.max
import kotlin.math.min

/**
 * A plain [CharacterStyle], not a `MetricAffectingSpan`, so nested strong/emphasis spans inside
 * ==highlight== keep their typeface and size. The background is a band [TextBackgroundDrawer]
 * draws from the text's layout rather than [TextPaint.bgColor], which fills the whole line box and
 * floats above the text once [LineHeightSpan] pads it out to the configured line height.
 */
class HighlightSpan(
  private val styleCache: SpanStyleCache,
  private val blockStyle: BlockStyle,
) : CharacterStyle() {
  private val foregroundColor = styleCache.getHighlightColorFor(blockStyle.color)
  private val backgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
  private val metrics = Paint.FontMetricsInt()

  override fun updateDrawState(textPaint: TextPaint) {
    textPaint.color = foregroundColor
  }

  /** Draws this span's band, from [spanStart] to [spanEnd], on [line] of [layout], from [lineStart] to [lineEnd]. */
  internal fun drawLine(
    canvas: Canvas,
    drawer: TextBackgroundDrawer,
    layout: Layout,
    line: Int,
    lineStart: Int,
    lineEnd: Int,
    spanStart: Int,
    spanEnd: Int,
  ) {
    val backgroundColor = styleCache.highlightBackgroundColor
    if (Color.alpha(backgroundColor) == 0 || spanEnd <= lineStart || spanStart >= lineEnd) return

    val startX = drawer.x(layout, line, lineStart, lineEnd, max(spanStart, lineStart))
    val endX = drawer.x(layout, line, lineStart, lineEnd, min(spanEnd, lineEnd))

    // Bound by the glyphs' ascent/descent, clamped to the line box so a tall line height never
    // lets the band bleed into its neighbours.
    val top = layout.getLineTop(line)
    val bottom = layout.getLineTop(line + 1)
    val baseline = layout.getLineBaseline(line)
    layout.paint.getFontMetricsInt(metrics)
    val bandTop = max(top.toFloat(), (baseline + metrics.ascent).toFloat())
    val bandBottom = min(bottom.toFloat(), (baseline + metrics.descent).toFloat())

    backgroundPaint.color = backgroundColor
    canvas.drawRect(min(startX, endX), bandTop, max(startX, endX), bandBottom, backgroundPaint)
  }
}
