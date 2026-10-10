package com.swmansion.enriched.markdown.plugin

import android.text.Spanned

/**
 * Implemented by replacement spans a plugin puts in the spannable, so core's markdown/HTML
 * export round-trips them without knowing what they are.
 */
@InternalPluginApi
interface PluginInlineSpan {
  /** Markdown source INCLUDING delimiters, e.g. `$x^2$`. Used by MarkdownExtractor. */
  fun toMarkdownSource(): String

  /** Text for HTML export, which core wraps in its inline-code styling. Null omits it. */
  fun toHtmlText(): String?

  /** Text standing in for the span in a plain-text copy. Null omits it. */
  fun toPlainText(): String?
}

/**
 * The text of [start]..[end] as it reads, rather than as it is stored: each plugin span inside the
 * range has its object-replacement character swapped for [PluginInlineSpan.toPlainText].
 */
@OptIn(InternalPluginApi::class)
internal fun Spanned.readableText(
  start: Int = 0,
  end: Int = length,
): String {
  val pluginSpans =
    getSpans(start, end, PluginInlineSpan::class.java)
      .filter { getSpanStart(it) >= start && getSpanEnd(it) <= end }
  if (pluginSpans.isEmpty()) return substring(start, end)

  val result = StringBuilder(subSequence(start, end))
  // Back to front, so replacing one span doesn't shift the offsets of those still to come.
  pluginSpans.sortedByDescending { getSpanStart(it) }.forEach { span ->
    result.replace(getSpanStart(span) - start, getSpanEnd(span) - start, span.toPlainText().orEmpty())
  }
  return result.toString()
}
