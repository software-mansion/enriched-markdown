package com.swmansion.enriched.markdown.spans

import android.text.TextPaint
import com.swmansion.enriched.markdown.renderer.SpanStyleCache
import com.swmansion.enriched.markdown.utils.text.extensions.applyColorPreserving

/**
 * Draws a strikethrough line and optionally recolors the struck run.
 *
 * Extends the framework span so consumers that look for [android.text.style.StrikethroughSpan]
 * — HTML/markdown export, accessibility, span parcelling on copy — keep working.
 */
class StrikethroughSpan(
  private val styleCache: SpanStyleCache,
) : android.text.style.StrikethroughSpan() {
  override fun updateDrawState(tp: TextPaint) {
    super.updateDrawState(tp)

    // A null color inherits whatever the surrounding block or a nested inline span set.
    styleCache.strikethroughColor?.let { tp.applyColorPreserving(it, *styleCache.colorsToPreserve) }
  }
}
