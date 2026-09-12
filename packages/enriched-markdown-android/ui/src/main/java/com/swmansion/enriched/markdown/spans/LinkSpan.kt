package com.swmansion.enriched.markdown.spans

import android.content.Context
import android.graphics.Color
import android.text.TextPaint
import android.text.style.ClickableSpan
import android.view.View
import com.swmansion.enriched.markdown.EnrichedMarkdownText
import com.swmansion.enriched.markdown.renderer.BlockStyle
import com.swmansion.enriched.markdown.renderer.SpanStyleCache
import com.swmansion.enriched.markdown.utils.text.extensions.applyBlockStyleFont

class LinkSpan(
  val url: String,
  private val onLinkPress: ((String) -> Unit)?,
  private val onLinkLongPress: ((String) -> Unit)?,
  private val styleCache: SpanStyleCache,
  private val blockStyle: BlockStyle,
  private val context: Context,
) : ClickableSpan() {
  @Volatile
  private var longPressTriggered = false

  override fun onClick(widget: View) {
    if (longPressTriggered) {
      longPressTriggered = false
      return
    }

    onLinkPress?.invoke(url) ?: (widget as? EnrichedMarkdownText)?.emitOnLinkPress(url)
  }

  fun onLongClick(widget: View): Boolean {
    longPressTriggered = true

    (widget as? EnrichedMarkdownText)?.emitOnLinkLongPress(url)

    onLinkLongPress?.invoke(url)

    return true
  }

  override fun updateDrawState(textPaint: TextPaint) {
    super.updateDrawState(textPaint)

    textPaint.textSize = blockStyle.fontSize

    val fontFamily = styleCache.linkFontFamily
    if (fontFamily.isNotEmpty()) {
      val overriddenBlockStyle = blockStyle.copy(fontFamily = fontFamily)
      textPaint.applyBlockStyleFont(overriddenBlockStyle, context)
    } else {
      textPaint.applyBlockStyleFont(blockStyle, context)
    }

    textPaint.color = styleCache.linkColor
    textPaint.isUnderlineText = styleCache.linkUnderline

    val backgroundColor = styleCache.linkBackgroundColor
    if (Color.alpha(backgroundColor) > 0) {
      textPaint.bgColor = backgroundColor
    }
  }
}
