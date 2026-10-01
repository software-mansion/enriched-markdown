package com.swmansion.enriched.markdown.spans

import android.text.TextPaint
import android.text.style.CharacterStyle
import com.swmansion.enriched.markdown.renderer.BlockStyle
import com.swmansion.enriched.markdown.renderer.SpanStyleCache
import com.swmansion.enriched.markdown.spoiler.colorWithAlpha

/** Conceals `||spoiler||` text by drawing it transparent; set last so no wrapper can recolor it. */
class SpoilerSpan(
  val styleCache: SpanStyleCache,
  val blockStyle: BlockStyle,
) : CharacterStyle() {
  var revealed = false
    private set
  var revealing = false
    private set

  /** How much of the text shows through: 0 while concealed, rising to 1 as the reveal fades it in. */
  internal var textAlpha = 0f

  fun markRevealing() {
    revealing = true
  }

  fun markRevealed() {
    revealed = true
    revealing = false
    textAlpha = 1f
  }

  override fun updateDrawState(tp: TextPaint) {
    if (revealed) return
    tp.color = colorWithAlpha(tp.color, textAlpha)
    tp.linkColor = colorWithAlpha(tp.linkColor, textAlpha)
    tp.bgColor = colorWithAlpha(tp.bgColor, textAlpha)
    tp.underlineColor = colorWithAlpha(tp.underlineColor, textAlpha)
  }
}
