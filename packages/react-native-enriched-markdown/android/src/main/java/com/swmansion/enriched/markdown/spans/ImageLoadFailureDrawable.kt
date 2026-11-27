package com.swmansion.enriched.markdown.spans

import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.drawable.Drawable
import android.text.TextPaint
import android.text.TextUtils
import androidx.core.graphics.ColorUtils
import kotlin.math.ceil
import kotlin.math.min

/**
 * What an image that could not be loaded shows instead: a tinted box with a picture
 * glyph and the alt text. Block images fill their box; inline images are a chip.
 */
internal class ImageLoadFailureDrawable(
  private val altText: String,
  color: Int,
  private val fontSize: Float,
  private val borderRadius: Float,
  private val isInline: Boolean,
  private val density: Float,
) : Drawable() {
  private val fillPaint =
    Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.FILL
      this.color = withAlpha(color, FILL_ALPHA)
    }
  private val glyphFillPaint =
    Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.FILL
      this.color = withAlpha(color, GLYPH_ALPHA)
    }
  private val glyphStrokePaint =
    Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.STROKE
      this.color = withAlpha(color, GLYPH_ALPHA)
    }
  private val textPaint =
    TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
      this.color = withAlpha(color, TEXT_ALPHA)
    }
  private val boxRect = RectF()
  private val glyphRect = RectF()
  private val glyphPath = Path()

  private fun chipFontSize(height: Int): Float = min(fontSize, height * CHIP_FONT_RATIO)

  /**
   * Square without alt text, otherwise as wide as the alt text needs, up to the chip cap
   * and [maxWidth], the line's width (0 when unknown).
   */
  fun chipWidth(
    height: Int,
    maxWidth: Int,
  ): Int {
    if (altText.isEmpty()) return height
    textPaint.textSize = chipFontSize(height)
    val padding = height * CHIP_PADDING_RATIO
    val width = padding + height * CHIP_GLYPH_RATIO + padding + ceil(textPaint.measureText(altText)) + padding
    val chipCap = (CHIP_MAX_WIDTH_DP * density).toInt()
    val cap = if (maxWidth > 0) min(chipCap, maxWidth) else chipCap
    return min(ceil(width).toInt(), cap).coerceAtLeast(height)
  }

  override fun draw(canvas: Canvas) {
    val width = bounds.width().toFloat()
    val height = bounds.height().toFloat()
    if (width <= 0f || height <= 0f) return

    boxRect.set(0f, 0f, width, height)
    val radius = if (isInline) height * CHIP_CORNER_RATIO else borderRadius
    canvas.drawRoundRect(boxRect, radius, radius, fillPaint)

    if (isInline) drawChipContent(canvas, width, height) else drawBlockContent(canvas, width, height)
  }

  private fun drawChipContent(
    canvas: Canvas,
    width: Float,
    height: Float,
  ) {
    val glyphSize = height * CHIP_GLYPH_RATIO
    val padding = height * CHIP_PADDING_RATIO
    val glyphTop = (height - glyphSize) / 2f

    if (altText.isEmpty()) {
      drawGlyph(canvas, (width - glyphSize) / 2f, glyphTop, glyphSize)
      return
    }

    drawGlyph(canvas, padding, glyphTop, glyphSize)
    textPaint.textSize = chipFontSize(height.toInt())
    textPaint.textAlign = Paint.Align.LEFT
    val textX = padding + glyphSize + padding
    val label = TextUtils.ellipsize(altText, textPaint, width - textX - padding, TextUtils.TruncateAt.END)
    canvas.drawText(label, 0, label.length, textX, centeredBaseline(height / 2f), textPaint)
  }

  private fun drawBlockContent(
    canvas: Canvas,
    width: Float,
    height: Float,
  ) {
    textPaint.textSize = fontSize
    textPaint.textAlign = Paint.Align.CENTER
    val glyphSize = min(BLOCK_GLYPH_MAX_DP * density, height * BLOCK_GLYPH_RATIO)
    val textHeight = if (altText.isEmpty()) 0f else textPaint.descent() - textPaint.ascent()
    val gap = if (textHeight > 0f) BLOCK_GAP_DP * density else 0f

    // A box too short for both keeps the alt text: it says what is missing.
    val showsGlyph = textHeight == 0f || glyphSize + gap + textHeight <= height
    val contentHeight = if (showsGlyph) glyphSize + gap + textHeight else textHeight
    var top = (height - contentHeight) / 2f

    if (showsGlyph) {
      drawGlyph(canvas, (width - glyphSize) / 2f, top, glyphSize)
      top += glyphSize + gap
    }
    if (textHeight > 0f) {
      val available = (width - BLOCK_TEXT_PADDING_DP * density * 2).coerceAtLeast(0f)
      val label = TextUtils.ellipsize(altText, textPaint, available, TextUtils.TruncateAt.END)
      canvas.drawText(label, 0, label.length, width / 2f, centeredBaseline(top + textHeight / 2f), textPaint)
    }
  }

  private fun centeredBaseline(centerY: Float): Float = centerY - (textPaint.descent() + textPaint.ascent()) / 2f

  // The same shape iOS and macOS draw, in the same proportions.
  private fun drawGlyph(
    canvas: Canvas,
    left: Float,
    top: Float,
    size: Float,
  ) {
    val lineWidth = (size * 0.08f).coerceAtLeast(density)
    glyphRect.set(left + lineWidth / 2f, top + size * 0.14f, left + size - lineWidth / 2f, top + size - size * 0.14f)
    val frameWidth = glyphRect.width()
    val frameHeight = glyphRect.height()
    val corner = size * 0.12f

    glyphStrokePaint.strokeWidth = lineWidth
    canvas.drawRoundRect(glyphRect, corner, corner, glyphStrokePaint)

    val sunRadius = size * 0.08f
    canvas.drawCircle(
      glyphRect.left + frameWidth * 0.62f + sunRadius,
      glyphRect.top + frameHeight * 0.18f + sunRadius,
      sunRadius,
      glyphFillPaint,
    )

    val floor = glyphRect.bottom - lineWidth
    glyphPath.rewind()
    glyphPath.moveTo(glyphRect.left + lineWidth, floor)
    glyphPath.lineTo(glyphRect.left + frameWidth * 0.36f, glyphRect.top + frameHeight * 0.42f)
    glyphPath.lineTo(glyphRect.left + frameWidth * 0.56f, glyphRect.top + frameHeight * 0.70f)
    glyphPath.lineTo(glyphRect.left + frameWidth * 0.70f, glyphRect.top + frameHeight * 0.54f)
    glyphPath.lineTo(glyphRect.right - lineWidth, floor)
    glyphPath.close()
    canvas.drawPath(glyphPath, glyphFillPaint)
  }

  override fun setAlpha(alpha: Int) = Unit

  override fun setColorFilter(colorFilter: ColorFilter?) = Unit

  @Suppress("DEPRECATION")
  @Deprecated("Deprecated in Java")
  override fun getOpacity(): Int = PixelFormat.TRANSLUCENT

  private companion object {
    const val CHIP_MAX_WIDTH_DP = 200f
    const val CHIP_PADDING_RATIO = 0.2f
    const val CHIP_GLYPH_RATIO = 0.7f
    const val CHIP_FONT_RATIO = 0.6f
    const val CHIP_CORNER_RATIO = 0.2f
    const val BLOCK_GLYPH_MAX_DP = 32f
    const val BLOCK_GLYPH_RATIO = 0.4f
    const val BLOCK_TEXT_PADDING_DP = 8f
    const val BLOCK_GAP_DP = 6f
    const val FILL_ALPHA = 0.08f
    const val GLYPH_ALPHA = 0.45f
    const val TEXT_ALPHA = 0.7f

    fun withAlpha(
      color: Int,
      alpha: Float,
    ): Int = ColorUtils.setAlphaComponent(color, (alpha * 255).toInt())
  }
}
