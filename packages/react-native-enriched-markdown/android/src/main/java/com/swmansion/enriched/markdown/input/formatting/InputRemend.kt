package com.swmansion.enriched.markdown.input.formatting

object InputRemend {
  private data class DelimiterPair(
    val open: String,
    val close: String,
    val symmetric: Boolean,
  )

  private val DELIMITER_PAIRS =
    arrayOf(
      DelimiterPair("***", "***", true),
      DelimiterPair("**", "**", true),
      DelimiterPair("*", "*", true),
      DelimiterPair("_", "_", true),
      DelimiterPair("~~", "~~", true),
      DelimiterPair("||", "||", true),
      DelimiterPair("`", "`", true),
      DelimiterPair("[", "]", false),
    )

  fun complete(markdown: String): String {
    if (markdown.isEmpty()) return markdown

    val stack = mutableListOf<String>()
    var inLinkParen = false
    val length = markdown.length
    var i = 0

    while (i < length) {
      val c = markdown[i]

      if (c == '\\' && i + 1 < length) {
        i += 2
        continue
      }

      if (c == ']' && !inLinkParen && i + 1 < length && markdown[i + 1] == '(') {
        val bracketIndex = stack.lastIndexOf("[")
        if (bracketIndex != -1) {
          stack.subList(bracketIndex, stack.size).clear()
        }
        inLinkParen = true
        i += 2
        continue
      }

      if (inLinkParen && c == ')') {
        inLinkParen = false
        i++
        continue
      }

      if (inLinkParen) {
        i++
        continue
      }

      var matched = false
      for (pair in DELIMITER_PAIRS) {
        val openLen = pair.open.length

        if (i + openLen > length) continue

        val substring = markdown.substring(i, i + openLen)

        if (pair.symmetric) {
          if (substring == pair.open) {
            if (stack.isNotEmpty() && stack.last() == pair.open) {
              stack.removeAt(stack.lastIndex)
            } else if (isLeftFlankingOpener(markdown, i, openLen)) {
              stack.add(pair.open)
            }
            i += openLen
            matched = true
            break
          }
        } else {
          if (substring == pair.open) {
            stack.add(pair.open)
            i += openLen
            matched = true
            break
          }
          val closeLen = pair.close.length
          if (i + closeLen <= length) {
            val closeSub = markdown.substring(i, i + closeLen)
            if (closeSub == pair.close) {
              if (stack.isNotEmpty() && stack.last() == pair.open) {
                stack.removeAt(stack.lastIndex)
              }
              i += closeLen
              matched = true
              break
            }
          }
        }
      }

      if (!matched) {
        i++
      }
    }

    val suffix = StringBuilder()

    if (inLinkParen) {
      suffix.append(")")
    }

    for (entry in stack.reversed()) {
      suffix.append(closingFor(entry))
    }

    if (suffix.isEmpty()) return markdown

    return markdown + suffix.toString()
  }

  private fun closingFor(entry: String): String = DELIMITER_PAIRS.firstOrNull { it.open == entry }?.close ?: entry

  /**
   * A symmetric delimiter can only start (and thus later need auto-closing) if it is
   * left-flanking: immediately followed by a non-whitespace character. A delimiter at
   * end-of-input or followed by whitespace cannot open emphasis in CommonMark, so
   * completing it would fabricate a marker md4c would never have produced.
   */
  private fun isLeftFlankingOpener(
    markdown: String,
    start: Int,
    openLen: Int,
  ): Boolean {
    val after = start + openLen
    return after < markdown.length && !markdown[after].isWhitespace()
  }
}
