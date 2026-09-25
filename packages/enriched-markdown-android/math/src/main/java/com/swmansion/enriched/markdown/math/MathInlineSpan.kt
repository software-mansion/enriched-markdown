package com.swmansion.enriched.markdown.math

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.text.style.ReplacementSpan
import com.swmansion.enriched.markdown.plugin.PluginEventSink
import com.swmansion.enriched.markdown.plugin.PluginInlineSpan
import io.ratex.RaTeXEngine
import io.ratex.RaTeXFontLoader
import io.ratex.RaTeXRenderer
import kotlin.math.ceil

/**
 * An inline equation, drawn as a bitmap over the single object-replacement character the renderer
 * put in the text. An expression the engine rejects falls back to its own source, so the reader
 * still sees what was written.
 *
 * The equation is laid out lazily, on the first [getSize]: that is the measure pass, not the
 * render thread, which matches how the block segment parses its latex in the view.
 */
class MathInlineSpan(
  val latex: String,
  val fontSize: Float,
  private val textColor: Int,
  private val onPluginEvent: PluginEventSink? = null,
) : ReplacementSpan(),
  PluginInlineSpan {
  private var cachedBitmap: Bitmap? = null
  private var cachedWidth = 0
  private var mathAscent = 0f
  private var mathDescent = 0f
  private var renderFailed = false

  private var fallbackText: String? = null

  /** The delimited source: core hands this straight to the clipboard, so it has to parse back. */
  override fun toMarkdownSource(): String = "\$" + latex + "\$"

  /** Bare latex: core wraps it in the inline-code styling HTML export uses for `$...$`. */
  override fun toHtmlText(): String = latex

  /** Bare latex, matching what the display-math segment's plain copy puts on the clipboard. */
  override fun toPlainText(): String = latex

  private fun prepareResources() {
    if (cachedBitmap != null && !cachedBitmap!!.isRecycled) return
    if (renderFailed) return

    runRaTeX(
      onFailure = { error ->
        renderFailed = true
        fallbackText = "\$" + latex + "\$"
        onPluginEvent?.emit(LatexErrorEvent(latex, error.message, displayMode = false))
      },
    ) {
      val displayList = RaTeXEngine.parseBlocking(latex, displayMode = false, color = textColor)
      val renderer = RaTeXRenderer(displayList, fontSize) { RaTeXFontLoader.getTypeface(it) }

      cachedWidth = renderer.widthPx.toInt().coerceAtLeast(1)
      mathAscent = renderer.heightPx
      mathDescent = renderer.depthPx

      val bitmap =
        Bitmap.createBitmap(
          cachedWidth,
          ceil(renderer.totalHeightPx).toInt().coerceAtLeast(1),
          Bitmap.Config.ARGB_8888,
        )

      renderer.draw(Canvas(bitmap))
      cachedBitmap = bitmap
    }
  }

  override fun getSize(
    paint: Paint,
    text: CharSequence?,
    start: Int,
    end: Int,
    fm: Paint.FontMetricsInt?,
  ): Int {
    prepareResources()

    val fallback = fallbackText
    if (fallback != null) {
      cachedWidth = ceil(paint.measureText(fallback)).toInt().coerceAtLeast(1)
      fm?.apply {
        val paintFm = paint.fontMetricsInt
        ascent = paintFm.ascent
        top = paintFm.top
        descent = paintFm.descent
        bottom = paintFm.bottom
      }
      return cachedWidth
    }

    fm?.apply {
      val ascentPx = ceil(mathAscent).toInt()
      ascent = -ascentPx
      top = ascent
      descent = (cachedBitmap?.height ?: ceil(mathAscent + mathDescent).toInt()) - ascentPx
      bottom = descent
    }

    return cachedWidth
  }

  override fun draw(
    canvas: Canvas,
    text: CharSequence?,
    start: Int,
    end: Int,
    x: Float,
    top: Int,
    y: Int,
    bottom: Int,
    paint: Paint,
  ) {
    prepareResources()

    val bitmap = cachedBitmap
    if (bitmap != null) {
      val bitmapY = y - ceil(mathAscent)
      canvas.drawBitmap(bitmap, x, bitmapY, paint)
      return
    }

    fallbackText?.let { fallback ->
      val originalColor = paint.color
      paint.color = textColor
      canvas.drawText(fallback, x, y.toFloat(), paint)
      paint.color = originalColor
    }
  }
}
