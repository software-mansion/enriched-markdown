package com.swmansion.enriched.markdown.utils.text.view

/**
 * Implemented by the commonmark host view (EnrichedMarkdownText) so
 * [LinkLongPressMovementMethod] can gate and dispatch taps that land on a
 * commonmark code block span without knowing the flavor.
 *
 * Only the commonmark flavor renders code blocks as spans inside the text view;
 * the GFM flavor uses a separate CodeBlockContainerView with its own tap
 * handling, so its host walk resolves to no CodeBlockPressHost.
 */
interface CodeBlockPressHost {
  val codeBlockPressEnabled: Boolean

  fun emitOnCodeBlockPress(
    code: String,
    language: String,
  )
}
