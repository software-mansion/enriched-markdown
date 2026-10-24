@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.math

import android.graphics.Canvas
import android.graphics.Paint
import android.text.Spanned
import android.text.style.ReplacementSpan
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PluginEventSink
import com.swmansion.enriched.markdown.plugin.PluginInlineSpan
import com.swmansion.enriched.markdown.spoiler.spoilerTextAlpha
import io.ratex.RaTeXFontLoader
import io.ratex.RaTeXRenderer
import kotlin.math.ceil

/**
 * An inline equation, drawn over the single object-replacement character the renderer put in the
 * text. [layOut] parses it on the render thread; measure and draw only read the result. An
 * expression the engine rejects gets no span: the renderer falls back to core's source text, which
 * already wraps, conceals and sizes like the text around it.
 */
class MathInlineSpan private constructor(
  val latex: String,
  val fontSize: Float,
  /** Whether the source was `$$...$$`; the equation is typeset inline either way. */
  val displayMode: Boolean,
  private val renderer: RaTeXRenderer,
) : ReplacementSpan(),
  PluginInlineSpan {
  private val mathAscent = ceil(renderer.heightPx).toInt()
  private val mathHeight = ceil(renderer.totalHeightPx).toInt().coerceAtLeast(1)
  private val mathWidth = ceil(renderer.widthPx).toInt().coerceAtLeast(1)

  private val delimitedSource: String = if (displayMode) "\$\$" + latex + "\$\$" else "\$" + latex + "\$"

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
    // The engine paints with its own colors, and the platform gives a replacement span a paint
    // without the spoiler's transparency applied, so concealment is read from the text instead.
    val visibility = (text as? Spanned)?.spoilerTextAlpha(start, end) ?: 1f
    if (visibility <= 0f) return
    val alpha = (visibility * OPAQUE).toInt()

    val mathTop = (y - mathAscent).toFloat()
    val saveCount =
      if (alpha < OPAQUE) {
        canvas.saveLayerAlpha(x, mathTop, x + mathWidth, mathTop + mathHeight, alpha)
      } else {
        canvas.save()
      }
    canvas.translate(x, mathTop)
    renderer.draw(canvas)
    canvas.restoreToCount(saveCount)
  }

  companion object {
    private const val OPAQUE = 255

    /**
     * Safe off the main thread: RaTeX's own async API runs the same parse on a background
     * dispatcher. Expects the KaTeX fonts to be loaded. Returns null when the engine rejects
     * [latex], after reporting it to [onPluginEvent].
     */
    fun layOut(
      latex: String,
      fontSize: Float,
      textColor: Int,
      displayMode: Boolean = false,
      onPluginEvent: PluginEventSink? = null,
    ): MathInlineSpan? {
      val renderer =
        runRaTeX(
          onFailure = { error -> onPluginEvent?.emit(LatexError(latex, error.message, displayMode)) },
        ) {
          val displayList = DisplayListCache.shared.get(latex, displayMode = false, color = textColor)
          RaTeXRenderer(displayList, fontSize) { RaTeXFontLoader.getTypeface(it) }
        } ?: return null
      return MathInlineSpan(latex, fontSize, displayMode, renderer)
    }
  }
}
