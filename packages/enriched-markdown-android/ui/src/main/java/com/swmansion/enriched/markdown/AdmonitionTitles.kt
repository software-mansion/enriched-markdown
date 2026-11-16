package com.swmansion.enriched.markdown

/**
 * Header titles for GitHub alerts (`> [!NOTE]`, …). Every type defaults to its English name; an
 * empty title shows the icon only.
 */
data class AdmonitionTitles(
  val note: String = "Note",
  val tip: String = "Tip",
  val important: String = "Important",
  val warning: String = "Warning",
  val caution: String = "Caution",
) {
  /** The header text for [type], on one line: the header draws a single line. */
  internal fun forType(type: String): String =
    when (type) {
      "note" -> note
      "tip" -> tip
      "important" -> important
      "warning" -> warning
      "caution" -> caution
      else -> type.replaceFirstChar { it.uppercase() }
    }.replace(LINE_BREAKS, " ").trim()

  companion object {
    val Default = AdmonitionTitles()

    private val LINE_BREAKS = Regex("[\\r\\n\\u0085\\u2028\\u2029]+")
  }
}
