package com.swmansion.enriched.markdown.spans

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.text.Spanned
import android.text.TextPaint
import android.text.style.CharacterStyle
import android.text.style.LineBackgroundSpan
import com.swmansion.enriched.markdown.renderer.BlockStyle
import com.swmansion.enriched.markdown.renderer.SpanStyleCache
import com.swmansion.enriched.markdown.spoiler.colorWithAlpha
import com.swmansion.enriched.markdown.spoiler.spoilerTextAlpha
import com.swmansion.enriched.markdown.utils.text.extensions.applyColorPreserving
import kotlin.math.max
import kotlin.math.min

/**
 * A plain [CharacterStyle], not a `MetricAffectingSpan`, so nested strong/emphasis spans inside
 * `==highlight==` keep their typeface and size. The background is a [LineBackgroundSpan] rather
 * than [TextPaint.bgColor], which fills the whole line box and floats above the text once
 * [LineHeightSpan] pads it out to the configured line height.
 */
class HighlightSpan(
  private val styleCache: SpanStyleCache,
  private val blockStyle: BlockStyle,
) : CharacterStyle(),
  LineBackgroundSpan {
  private val backgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
  private val metricsPaint = TextPaint()

  override fun updateDrawState(tp: TextPaint) {
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

    // A band under a concealed spoiler would outline the hidden text, so it fades in with the text
    // instead.
    val visibility = text.spoilerTextAlpha(maxOf(spanStart, start), minOf(spanEnd, end))
    if (visibility <= 0f) return

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

    // Bound by the glyphs' ascent/descent, clamped to the line box so a tall line height never
    // lets the band bleed into its neighbours. `p` is set in the view's size, so measure with the
    // block's (e.g. a heading's) instead.
    metricsPaint.set(p)
    metricsPaint.textSize = blockStyle.fontSize
    val metrics = metricsPaint.fontMetricsInt
    val bandTop = max(top.toFloat(), (baseline + metrics.ascent).toFloat())
    val bandBottom = min(bottom.toFloat(), (baseline + metrics.descent).toFloat())

    backgroundPaint.color = colorWithAlpha(backgroundColor, visibility)
    canvas.drawRect(min(startX, endX), bandTop, max(startX, endX), bandBottom, backgroundPaint)
  }
}
