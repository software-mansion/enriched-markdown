package com.swmansion.enriched.markdown

/**
 * Payload for a code block copy: the code that went to the clipboard, and the fence's
 * info string, or null when the fence named no language.
 */
data class CodeBlockCopy(
  val code: String,
  val language: String?,
)
