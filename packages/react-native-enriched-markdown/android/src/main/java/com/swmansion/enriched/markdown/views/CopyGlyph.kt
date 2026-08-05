package com.swmansion.enriched.markdown.views

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode

/**
 * Draws the copy glyph so Android matches the SF Symbol doc.on.doc rendered on
 * iOS: two portrait document pages with a folded (dog-eared) top-right corner,
 * a front page in the lower-left laid over a back page in the upper-right.
 *
 * The back page is punched out where the front page (plus a hairline of
 * clearance) covers it, so the front reads as sitting on top exactly as the SF
 * Symbol does, instead of both outlines crossing. The clear is done inside an
 * offscreen layer so the punched region reveals whatever background the drawable
 * sits on, without the glyph needing to know that color.
 *
 * All coordinates use a 24-unit grid scaled to the drawable width, matching the
 * grid the iOS symbol is authored on.
 */
internal object CopyGlyph {
  private val clearXfermode = PorterDuffXfermode(PorterDuff.Mode.CLEAR)

  fun draw(
    canvas: Canvas,
    width: Float,
    stroke: Paint,
  ) {
    val u = width / 24f
    val fold = 4f * u
    val corner = 2f * u

    val back = pagePath(9 * u, 1 * u, 20 * u, 17 * u, fold, corner)
    val front = pagePath(3 * u, 7 * u, 14 * u, 23 * u, fold, corner)

    val clear =
      Paint(stroke).apply {
        style = Paint.Style.FILL_AND_STROKE
        strokeWidth = stroke.strokeWidth * 3f
        colorFilter = null
        xfermode = clearXfermode
      }

    val saved = canvas.saveLayer(0f, 0f, width, width, null)
    canvas.drawPath(back, stroke)
    canvas.drawPath(foldPath(20 * u, 1 * u, fold), stroke)
    canvas.drawPath(front, clear)
    canvas.drawPath(front, stroke)
    canvas.drawPath(foldPath(14 * u, 7 * u, fold), stroke)
    canvas.restoreToCount(saved)
  }

  // A page outline whose top-right corner is cut back by fold, with the other
  // three corners rounded by corner.
  private fun pagePath(
    l: Float,
    t: Float,
    r: Float,
    b: Float,
    fold: Float,
    corner: Float,
  ): Path =
    Path().apply {
      moveTo(l, t + corner)
      quadTo(l, t, l + corner, t)
      lineTo(r - fold, t)
      lineTo(r, t + fold)
      lineTo(r, b - corner)
      quadTo(r, b, r - corner, b)
      lineTo(l + corner, b)
      quadTo(l, b, l, b - corner)
      close()
    }

  // The two inner edges of the folded-over corner, at the page's top-right.
  private fun foldPath(
    r: Float,
    t: Float,
    fold: Float,
  ): Path =
    Path().apply {
      moveTo(r - fold, t)
      lineTo(r - fold, t + fold)
      lineTo(r, t + fold)
    }
}
