package com.swmansion.enriched.markdown.compose

import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import com.swmansion.enriched.markdown.spoiler.CustomSpoilerOverlay
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlayHost
import com.swmansion.enriched.markdown.spoiler.SpoilerSegment
import com.swmansion.enriched.markdown.spoiler.SpoilerSegmentOverlay
import android.graphics.Canvas as NativeCanvas
import androidx.compose.ui.graphics.Canvas as ComposeCanvas

/**
 * A [SpoilerSegmentOverlay] drawn with Compose; return instances from
 * [CustomSpoilerOverlay.createSegment]. Each call gets a [DrawScope] clipped to the segment, with
 * the host's [Density] and a [LayoutDirection] that follows [SpoilerSegment.isRtl].
 */
abstract class DrawScopeSpoilerSegmentOverlay(
  private val host: SpoilerOverlayHost,
) : SpoilerSegmentOverlay() {
  private var density = Density(host.density, host.fontScale)
  private val drawScope = CanvasDrawScope()

  private var nativeCanvas: NativeCanvas? = null
  private var composeCanvas: ComposeCanvas? = null

  /** Draws the concealed segment. [segment] describes it as of this frame. */
  abstract fun DrawScope.draw(segment: SpoilerSegment)

  /** See [SpoilerSegmentOverlay.drawReveal]. The default is [drawFadingOut]. */
  open fun DrawScope.drawReveal(
    segment: SpoilerSegment,
    progress: Float,
  ) {
    drawFadingOut(segment, progress)
  }

  /** Draws [DrawScope.draw] faded out by [progress], as the text fades in underneath. */
  protected fun DrawScope.drawFadingOut(
    segment: SpoilerSegment,
    progress: Float,
  ) {
    // The fade lives in the base class, which draws back through draw(canvas, segment).
    super.drawReveal(drawContext.canvas.nativeCanvas, segment, progress)
  }

  final override fun draw(
    canvas: NativeCanvas,
    segment: SpoilerSegment,
  ) {
    drawScope.draw(currentDensity(), segment.layoutDirection, wrap(canvas), Size(segment.width, segment.height)) {
      draw(segment)
    }
  }

  final override fun drawReveal(
    canvas: NativeCanvas,
    segment: SpoilerSegment,
    progress: Float,
  ) {
    drawScope.draw(currentDensity(), segment.layoutDirection, wrap(canvas), Size(segment.width, segment.height)) {
      drawReveal(segment, progress)
    }
  }

  private fun currentDensity(): Density {
    val hostDensity = host.density
    val fontScale = host.fontScale
    if (density.density != hostDensity || density.fontScale != fontScale) density = Density(hostDensity, fontScale)
    return density
  }

  private fun wrap(canvas: NativeCanvas): ComposeCanvas {
    val wrapped = composeCanvas
    if (wrapped != null && nativeCanvas === canvas) return wrapped
    nativeCanvas = canvas
    return ComposeCanvas(canvas).also { composeCanvas = it }
  }

  private val SpoilerSegment.layoutDirection: LayoutDirection
    get() = if (isRtl) LayoutDirection.Rtl else LayoutDirection.Ltr
}

/** See [SpoilerSegment.drawText]. The scope's current transform applies. */
fun DrawScope.drawSegmentText(segment: SpoilerSegment) {
  segment.drawText(drawContext.canvas.nativeCanvas)
}
