package com.swmansion.enriched.markdown.views

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF

/**
 * Material "wrap_text" glyph as strokes on a 24-unit grid, drawn with the same
 * paint as [CopyGlyph] so the two header buttons match in weight.
 */
internal class WrapGlyph {
  private val lines = Path()
  private val arrow = Path()
  private val loop = RectF()

  fun draw(
    canvas: Canvas,
    width: Float,
    stroke: Paint,
  ) {
    val u = width / 24f
    lines.rewind()
    lines.moveTo(4 * u, 6 * u)
    lines.lineTo(20 * u, 6 * u)
    lines.moveTo(4 * u, 18 * u)
    lines.lineTo(10 * u, 18 * u)
    lines.moveTo(4 * u, 12 * u)
    lines.lineTo(17 * u, 12 * u)
    loop.set(15 * u, 12 * u, 19 * u, 16 * u)
    lines.arcTo(loop, -90f, 180f)
    lines.lineTo(13 * u, 16 * u)
    arrow.rewind()
    arrow.moveTo(15 * u, 14 * u)
    arrow.lineTo(13 * u, 16 * u)
    arrow.lineTo(15 * u, 18 * u)
    canvas.drawPath(lines, stroke)
    canvas.drawPath(arrow, stroke)
  }
}
