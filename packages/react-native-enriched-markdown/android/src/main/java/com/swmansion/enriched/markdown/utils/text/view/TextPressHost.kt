package com.swmansion.enriched.markdown.utils.text.view

/**
 * Implemented by the React-tagged host views (EnrichedMarkdownText and the GFM
 * EnrichedMarkdown container) so [LinkLongPressMovementMethod] can gate and
 * dispatch taps on plain text, the same way [ImagePressHost] routes image taps.
 */
interface TextPressHost {
  val textPressEnabled: Boolean

  fun emitOnTextPress(
    index: Int,
    text: String,
  )
}
