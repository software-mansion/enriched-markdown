package com.swmansion.enriched.markdown

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import com.swmansion.enriched.markdown.spoiler.CustomSpoilerOverlay
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlayHost
import com.swmansion.enriched.markdown.spoiler.SpoilerSegment
import com.swmansion.enriched.markdown.spoiler.SpoilerSegmentOverlay
import com.swmansion.enriched.markdown.styles.SpoilerStyle

// The Canvas custom overlay example from the README, kept here so it keeps compiling. Keep it in
// sync with the README and with the example app's copy in PlaygroundSpoilerOverlay.kt.

data class PixelatedSpoiler(
  val blockSize: Float = 6f,
) : CustomSpoilerOverlay {
  override fun createSegmentOverlay(
    host: SpoilerOverlayHost,
    style: SpoilerStyle,
  ) = PixelatedSegment(blockSize * host.density)
}

class PixelatedSegment(
  private val blockSize: Float,
) : SpoilerSegmentOverlay() {
  // Paint filters bitmaps by default since Android 10; turn it off so the blocks keep hard edges.
  private val paint = Paint().apply { isFilterBitmap = false }
  private val bounds = RectF()
  private var pixels: Bitmap? = null

  override fun draw(
    canvas: Canvas,
    segment: SpoilerSegment,
  ) {
    val columns = (segment.width / blockSize).toInt().coerceAtLeast(1)
    val rows = (segment.height / blockSize).toInt().coerceAtLeast(1)
    val image =
      pixels?.takeIf { it.width == columns && it.height == rows }
        ?: Bitmap.createBitmap(columns, rows, Bitmap.Config.ARGB_8888).also { bitmap ->
          // The text, shrunk to one pixel per block.
          Canvas(bitmap).apply {
            scale(columns / segment.width, rows / segment.height)
            segment.drawText(this)
          }
          pixels = bitmap
        }
    bounds.set(0f, 0f, segment.width, segment.height)
    canvas.drawBitmap(image, null, bounds, paint)
  }

  override fun onRemoved() {
    pixels = null
  }
}
