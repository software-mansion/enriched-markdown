@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.math

import android.graphics.Canvas
import android.graphics.Paint
import android.text.style.ReplacementSpan
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PluginEventSink
import com.swmansion.enriched.markdown.plugin.PluginInlineSpan
import io.ratex.RaTeXEngine
import io.ratex.RaTeXFontLoader
import io.ratex.RaTeXRenderer
import kotlin.math.ceil

/**
 * An inline equation, drawn over the single object-replacement character the renderer put in the
 * text. An expression the engine rejects falls back to its own source, so the reader still sees
 * what was written. [layOut] parses it on the render thread; measure and draw only read the result.
 */
class MathInlineSpan private constructor(
  val latex: String,
  val fontSize: Float,
  private val textColor: Int,
  /** Whether the source was `$$...$$`; the equation is typeset inline either way. */
  val displayMode: Boolean,
  /** Null when the engine rejected [latex]. */
  private val renderer: RaTeXRenderer?,
) : ReplacementSpan(),
  PluginInlineSpan {
  private val mathAscent = renderer?.let { ceil(it.heightPx).toInt() } ?: 0
  private val mathHeight = renderer?.let { ceil(it.totalHeightPx).toInt().coerceAtLeast(1) } ?: 0
  private val mathWidth = renderer?.let { ceil(it.widthPx).toInt().coerceAtLeast(1) } ?: 0

  private val delimitedSource: String = if (displayMode) "\$\$" + latex + "\$\$" else "\$" + latex + "\$"

  private val fallbackText: String? = if (renderer == null) delimitedSource else null

  /** The delimited source: core hands this straight to the clipboard, so it has to parse back. */
  override fun toMarkdownSource(): String = delimitedSource

  /** Bare latex: core wraps it in the inline-code styling HTML export uses for `$...$`. */
  override fun toHtmlText(): String = latex

  /** Bare latex, matching what the display-math segment's plain copy puts on the clipboard. */
  override fun toPlainText(): String = latex

  override fun getSize(
    paint: Paint,
    text: CharSequence?,
    start: Int,
    end: Int,
    fm: Paint.FontMetricsInt?,
  ): Int {
    val fallback = fallbackText
    if (fallback != null) {
      fm?.apply {
        val paintFm = paint.fontMetricsInt
        ascent = paintFm.ascent
        top = paintFm.top
        descent = paintFm.descent
        bottom = paintFm.bottom
      }
      return ceil(paint.measureText(fallback)).toInt().coerceAtLeast(1)
    }

    fm?.apply {
      ascent = -mathAscent
      top = ascent
      descent = mathHeight - mathAscent
      bottom = descent
    }
    return mathWidth
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
    val currentRenderer = renderer
    if (currentRenderer != null) {
      val saveCount = canvas.save()
      canvas.translate(x, (y - mathAscent).toFloat())
      currentRenderer.draw(canvas)
      canvas.restoreToCount(saveCount)
      return
    }

    fallbackText?.let { fallback ->
      val originalColor = paint.color
      paint.color = textColor
      canvas.drawText(fallback, x, y.toFloat(), paint)
      paint.color = originalColor
    }
  }

  companion object {
    /**
     * Safe off the main thread: RaTeX's own async API runs the same parse on a background
     * dispatcher. Expects the KaTeX fonts to be loaded; a failure is reported to [onPluginEvent].
     */
    fun layOut(
      latex: String,
      fontSize: Float,
      textColor: Int,
      displayMode: Boolean = false,
      onPluginEvent: PluginEventSink? = null,
    ): MathInlineSpan {
      val renderer =
        runRaTeX(
          onFailure = { error -> onPluginEvent?.emit(LatexErrorEvent(latex, error.message, displayMode)) },
        ) {
          val displayList = RaTeXEngine.parseBlocking(latex, displayMode = false, color = textColor)
          RaTeXRenderer(displayList, fontSize) { RaTeXFontLoader.getTypeface(it) }
        }
      return MathInlineSpan(latex, fontSize, textColor, displayMode, renderer)
    }
  }
}
