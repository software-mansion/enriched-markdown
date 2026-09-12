package com.swmansion.enriched.markdown.input.editing

import com.swmansion.enriched.markdown.input.model.BlockType

/**
 * Recognizes the markdown block prefixes a user types at the start of a
 * paragraph — `#`…`######`, `-`/`*`/`+`, `1.`/`1)` — so the input can turn the
 * paragraph into the matching block and drop the prefix (Notion-style markdown
 * shortcuts). Pure text matching; the caller owns the mutation.
 */
internal object MarkdownShortcutMatcher {
  data class Match(
    val type: BlockType,
    val level: Int,
  )

  /** Anything longer is a number the user is writing, not a list marker. */
  private const val MAX_ORDERED_MARKER_DIGITS = 9

  /**
   * Matches [prefix] (the paragraph text before the space the user just typed,
   * with no leading whitespace). Ordered items match any number — the block
   * store renumbers ordinals, so `3.` on a fresh line still starts at 1.
   */
  fun match(prefix: CharSequence): Match? {
    if (prefix.isEmpty()) return null
    val first = prefix[0]

    if (first == '#') {
      if (prefix.length > 6 || !prefix.all { it == '#' }) return null
      val type = BlockType.forHeadingLevel(prefix.length) ?: return null
      return Match(type, prefix.length)
    }

    if (prefix.length == 1 && (first == '-' || first == '*' || first == '+')) {
      return Match(BlockType.UNORDERED_LIST_ITEM, 0)
    }

    val last = prefix.last()
    if ((last == '.' || last == ')') && prefix.length >= 2 && prefix.length - 1 <= MAX_ORDERED_MARKER_DIGITS) {
      if (prefix.subSequence(0, prefix.length - 1).all { it in '0'..'9' }) {
        return Match(BlockType.ORDERED_LIST_ITEM, 0)
      }
    }
    return null
  }
}
