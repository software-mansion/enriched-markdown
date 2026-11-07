package com.swmansion.enriched.markdown.views

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path

// Stroked checkmark on the same 24-unit grid as CopyGlyph, matching the SF Symbol "checkmark" shown on iOS.
internal class CheckmarkGlyph {
  private val path = Path()

  fun draw(
    canvas: Canvas,
    width: Float,
    stroke: Paint,
  ) {
    val u = width / 24f
    path.rewind()
    path.moveTo(4 * u, 12.5f * u)
    path.lineTo(9.5f * u, 18 * u)
    path.lineTo(20 * u, 6 * u)
    canvas.drawPath(path, stroke)
  }
}
