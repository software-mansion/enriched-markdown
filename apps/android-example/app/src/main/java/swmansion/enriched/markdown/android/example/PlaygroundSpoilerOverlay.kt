package swmansion.enriched.markdown.android.example

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.swmansion.enriched.markdown.compose.DrawScopeSpoilerSegmentOverlay
import com.swmansion.enriched.markdown.compose.invoke
import com.swmansion.enriched.markdown.spoiler.CustomSpoilerOverlay
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlay
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlayHost
import com.swmansion.enriched.markdown.spoiler.SpoilerSegment
import com.swmansion.enriched.markdown.spoiler.SpoilerSegmentOverlay
import com.swmansion.enriched.markdown.styles.SpoilerStyle

/**
 * The overlays the Playground's "Spoiler" button cycles through. Each entry holds one overlay
 * instance, so recomposing the screen passes the same value and running overlays keep going.
 */
enum class PlaygroundSpoilerOverlay(
  val label: String,
  val overlay: SpoilerOverlay,
) {
  Particles("Particles", SpoilerOverlay.Particles()),
  DenseParticles("Dense particles", SpoilerOverlay.Particles(density = 20f, speed = 45f)),
  Solid("Solid", SpoilerOverlay.Solid(cornerRadius = 6.dp)),
  Shimmer("Shimmer", ShimmerSpoiler()),
  Pixelated("Pixelated", PixelatedSpoiler()),
  ;

  val next: PlaygroundSpoilerOverlay get() = entries[(ordinal + 1) % entries.size]
}

/** Markdown with spoilers in the places overlays have to cope with. */
fun spoilerSampleMarkdown(inlineImageUri: String): String =
  """
  ## A heading with a ||hidden|| word

  A long spoiler wraps, and every line gets its own overlay: ||the oldest known living tree is a Great Basin bristlecone pine in the White Mountains of California, over 4,850 years old||.

  Styled spoilers: ||**Methuselah**, *the tree's nickname*|| and ||a [link](https://en.wikipedia.org/wiki/Bristlecone_pine) inside||.

  Emoji and an inline image: ||🌲🌳 ![icon]($inlineImageUri) forest||.

  Right to left: ||שלום עולם, זהו ספוילר||.
  """.trimIndent()

// A custom overlay drawn with Compose (DrawScope, Brush, Color).

/**
 * The README's Compose example: a band of light sweeping across a rounded box, which wipes away in
 * reading order when revealed. Keep it in sync with the README.
 */
data class ShimmerSpoiler(
  val periodMillis: Long = 1_500,
) : CustomSpoilerOverlay {
  override fun createSegmentOverlay(
    host: SpoilerOverlayHost,
    style: SpoilerStyle,
  ) = ShimmerSegment(host, Color(style.color), periodMillis)
}

class ShimmerSegment(
  host: SpoilerOverlayHost,
  private val color: Color,
  private val periodMillis: Long,
) : DrawScopeSpoilerSegmentOverlay(host) {
  // A band of light, made once and moved with translate(): a new Brush each frame is a new shader.
  private val band = 32 * host.density
  private val shine =
    Brush.horizontalGradient(
      listOf(Color.Transparent, Color.White.copy(alpha = 0.35f), Color.Transparent),
      startX = -band,
      endX = band,
    )

  override val isAnimated get() = true

  override fun DrawScope.draw(segment: SpoilerSegment) {
    drawRoundRect(color, cornerRadius = CornerRadius(4.dp.toPx()))
    // The band sweeps across in reading order, once per period.
    val phase = (segment.frameTimeMillis % periodMillis) / periodMillis.toFloat()
    val travelled = -band + (size.width + 2 * band) * phase
    val center = if (layoutDirection == LayoutDirection.Ltr) travelled else size.width - travelled
    translate(left = center) {
      drawRect(shine, topLeft = Offset(-band, 0f), size = Size(2 * band, size.height))
    }
  }

  // Wipes the box away in reading order, instead of the default fade.
  override fun DrawScope.drawReveal(
    segment: SpoilerSegment,
    progress: Float,
  ) {
    val covered = size.width * (1f - progress)
    val left = if (layoutDirection == LayoutDirection.Ltr) size.width - covered else 0f
    clipRect(left = left, right = left + covered) { draw(segment) }
  }
}

// A custom overlay drawn on the text view's Canvas, showing the text through.

/**
 * The README's Canvas example: the hidden text, shrunk to one pixel per block and scaled back up, so
 * its shape shows but the words don't. Keep it in sync with the README.
 */
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
