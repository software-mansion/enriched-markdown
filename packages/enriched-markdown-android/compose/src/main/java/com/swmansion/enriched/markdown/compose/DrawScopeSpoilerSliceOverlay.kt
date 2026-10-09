package com.swmansion.enriched.markdown.compose

import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import com.swmansion.enriched.markdown.spoiler.CustomSpoilerOverlay
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlayHost
import com.swmansion.enriched.markdown.spoiler.SpoilerSlice
import com.swmansion.enriched.markdown.spoiler.SpoilerSliceOverlay
import android.graphics.Canvas as NativeCanvas
import androidx.compose.ui.graphics.Canvas as ComposeCanvas

/**
 * A [SpoilerSliceOverlay] drawn with Compose; return instances from
 * [CustomSpoilerOverlay.createSliceOverlay]. Each call gets a [DrawScope] clipped to the slice,
 * with the host's [Density] and a [LayoutDirection] that follows [SpoilerSlice.isRtl].
 */
abstract class DrawScopeSpoilerSliceOverlay(
  private val host: SpoilerOverlayHost,
) : SpoilerSliceOverlay() {
  private var density = Density(host.density, host.fontScale)
  private val drawScope = CanvasDrawScope()

  private var nativeCanvas: NativeCanvas? = null
  private var composeCanvas: ComposeCanvas? = null

  /** Draws the concealed slice. [slice] describes it as of this frame. */
  abstract fun DrawScope.draw(slice: SpoilerSlice)

  /** See [SpoilerSliceOverlay.drawReveal]. The default is [drawFadingOut]. */
  open fun DrawScope.drawReveal(
    slice: SpoilerSlice,
    progress: Float,
  ) {
    drawFadingOut(slice, progress)
  }

  /** Draws [DrawScope.draw] faded out by [progress], as the text fades in underneath. */
  protected fun DrawScope.drawFadingOut(
    slice: SpoilerSlice,
    progress: Float,
  ) {
    // The fade lives in the base class, which draws back through draw(canvas, slice).
    super.drawReveal(drawContext.canvas.nativeCanvas, slice, progress)
  }

  final override fun draw(
    canvas: NativeCanvas,
    slice: SpoilerSlice,
  ) {
    drawScope.draw(currentDensity(), slice.layoutDirection, wrap(canvas), Size(slice.width, slice.height)) {
      draw(slice)
    }
  }

  final override fun drawReveal(
    canvas: NativeCanvas,
    slice: SpoilerSlice,
    progress: Float,
  ) {
    drawScope.draw(currentDensity(), slice.layoutDirection, wrap(canvas), Size(slice.width, slice.height)) {
      drawReveal(slice, progress)
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

  private val SpoilerSlice.layoutDirection: LayoutDirection
    get() = if (isRtl) LayoutDirection.Rtl else LayoutDirection.Ltr
}

/** See [SpoilerSlice.drawText]. The scope's current transform applies. */
fun DrawScope.drawSliceText(slice: SpoilerSlice) {
  slice.drawText(drawContext.canvas.nativeCanvas)
}
