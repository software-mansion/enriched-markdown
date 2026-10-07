package com.swmansion.enriched.markdown.spoiler

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF

internal class SolidSegmentOverlay(
  private val color: Int,
  private val cornerRadius: Float,
) : SpoilerSegmentOverlay() {
  private val paint = Paint()
  private val rect = RectF()

  override fun draw(
    canvas: Canvas,
    segment: SpoilerSegment,
  ) = drawBox(canvas, segment, alpha = 1f)

  // Fading the paint matches the default's layer fade for a single shape, without the layer.
  override fun drawReveal(
    canvas: Canvas,
    segment: SpoilerSegment,
    progress: Float,
  ) = drawBox(canvas, segment, overlayAlphaAt(progress))

  private fun drawBox(
    canvas: Canvas,
    segment: SpoilerSegment,
    alpha: Float,
  ) {
    paint.color = colorWithAlpha(color, alpha)
    rect.set(0f, 0f, segment.width, segment.height)
    canvas.drawRoundRect(rect, cornerRadius, cornerRadius, paint)
  }
}
