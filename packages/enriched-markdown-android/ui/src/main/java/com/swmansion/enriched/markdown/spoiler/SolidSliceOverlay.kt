package com.swmansion.enriched.markdown.spoiler

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF

internal class SolidSliceOverlay(
  private val color: Int,
  private val cornerRadius: Float,
) : SpoilerSliceOverlay() {
  private val paint = Paint()
  private val rect = RectF()

  override fun draw(
    canvas: Canvas,
    slice: SpoilerSlice,
  ) = drawBox(canvas, slice, alpha = 1f)

  // Fading the paint matches the default's layer fade for a single shape, without the layer.
  override fun drawReveal(
    canvas: Canvas,
    slice: SpoilerSlice,
    progress: Float,
  ) = drawBox(canvas, slice, overlayAlphaAt(progress))

  private fun drawBox(
    canvas: Canvas,
    slice: SpoilerSlice,
    alpha: Float,
  ) {
    paint.color = colorWithAlpha(color, alpha)
    rect.set(0f, 0f, slice.width, slice.height)
    canvas.drawRoundRect(rect, cornerRadius, cornerRadius, paint)
  }
}
