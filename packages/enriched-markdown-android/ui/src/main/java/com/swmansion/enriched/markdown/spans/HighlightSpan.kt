package com.swmansion.enriched.markdown.spans

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.text.Spanned
import android.text.TextPaint
import android.text.style.CharacterStyle
import android.text.style.LineBackgroundSpan
import com.swmansion.enriched.markdown.renderer.SpanStyleCache
import com.swmansion.enriched.markdown.utils.text.extensions.applyColorPreserving
import kotlin.math.max
import kotlin.math.min

/**
 * Paints the highlight background and optionally recolors the highlighted run.
 *
 * Deliberately a plain [CharacterStyle] rather than a `MetricAffectingSpan`: it must not reset
 * the typeface or text size, so nested strong/emphasis spans inside `==highlight==` keep working.
 *
 * The background is drawn here as a [LineBackgroundSpan] rather than set through
 * [TextPaint.bgColor], because that fills the full line box — which [LineHeightSpan] pads above
 * and below to reach the configured line height, leaving the highlight floating well above the
 * text it marks. Measuring from the baseline instead keeps the band tight to the glyphs.
 */
class HighlightSpan(
  private val styleCache: SpanStyleCache,
) : CharacterStyle(),
  LineBackgroundSpan {
  private val backgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }

  override fun updateDrawState(tp: TextPaint) {
    // A null color inherits whatever the surrounding block or a nested inline span set.
    styleCache.highlightColor?.let { tp.applyColorPreserving(it, *styleCache.colorsToPreserve) }
  }

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
    lineNum: Int,
  ) {
    val backgroundColor = styleCache.highlightBackgroundColor
    if (Color.alpha(backgroundColor) == 0) return
    if (text !is Spanned) return

    val spanStart = text.getSpanStart(this)
    val spanEnd = text.getSpanEnd(this)
    if (spanStart !in 0 until spanEnd) return

    val isFirst = spanStart >= start
    val isLast = spanEnd <= end

    val leadingMargin = InlineBackgroundGeometry.leadingMarginAt(text, start)
    val startX =
      if (isFirst) {
        InlineBackgroundGeometry.horizontalOffset(text, start, end, spanStart, p, leadingMargin) + left
      } else {
        left.toFloat() + leadingMargin
      }
    val endX =
      if (isLast) {
        InlineBackgroundGeometry.horizontalOffset(text, start, end, spanEnd, p, leadingMargin) + left
      } else {
        right.toFloat()
      }

    // Bound the band by the glyphs' own ascent/descent around the baseline, not by the line
    // box, then clamp so a tall line-height never lets it bleed into the neighbouring lines.
    val metrics = p.fontMetricsInt
    val bandTop = max(top.toFloat(), (baseline + metrics.ascent).toFloat())
    val bandBottom = min(bottom.toFloat(), (baseline + metrics.descent).toFloat())

    backgroundPaint.color = backgroundColor
    canvas.drawRect(min(startX, endX), bandTop, max(startX, endX), bandBottom, backgroundPaint)
  }
}
