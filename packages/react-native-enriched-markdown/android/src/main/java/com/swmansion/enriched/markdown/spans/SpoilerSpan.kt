package com.swmansion.enriched.markdown.spans

import android.os.Build
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

  /**
   * Bumped when what the span covers changes without the text moving, as when an image under it
   * loads, so overlays that cached the concealed content start over.
   */
  internal var contentVersion = 0

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
    // Public from API 29; below that, underlines are drawn in `color`, which is already faded.
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      tp.underlineColor = colorWithAlpha(tp.underlineColor, textAlpha)
    }
  }
}
