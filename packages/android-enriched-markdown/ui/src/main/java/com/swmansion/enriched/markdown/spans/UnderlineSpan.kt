package com.swmansion.enriched.markdown.spans

import android.text.TextPaint
import com.swmansion.enriched.markdown.renderer.SpanStyleCache
import com.swmansion.enriched.markdown.utils.text.extensions.applyColorPreserving

/**
 * Draws an underline and optionally recolors the underlined run.
 *
 * Extends the framework span so consumers that look for [android.text.style.UnderlineSpan]
 * — HTML/markdown export, accessibility, span parcelling on copy — keep working.
 */
class UnderlineSpan(
  private val styleCache: SpanStyleCache,
) : android.text.style.UnderlineSpan() {
  override fun updateDrawState(tp: TextPaint) {
    super.updateDrawState(tp)

    // A null color inherits whatever the surrounding block or a nested inline span set.
    styleCache.underlineColor?.let { tp.applyColorPreserving(it, *styleCache.colorsToPreserve) }
  }
}
