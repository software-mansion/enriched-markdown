package com.swmansion.enriched.markdown.plugin

/**
 * Implemented by replacement spans a plugin puts in the spannable, so core's markdown/HTML
 * export round-trips them without knowing what they are.
 */
interface PluginInlineSpan {
  /** Markdown source INCLUDING delimiters, e.g. `$x^2$`. Used by MarkdownExtractor. */
  fun toMarkdownSource(): String

  /** Text for HTML export, which core wraps in its inline-code styling. Null omits it. */
  fun toHtmlText(): String?

  /** Text standing in for the span in a plain-text copy. Null omits it. */
  fun toPlainText(): String?
}
