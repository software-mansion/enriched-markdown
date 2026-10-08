package com.swmansion.enriched.markdown.utils.text.view

import android.text.Spanned
import com.swmansion.enriched.markdown.spans.LinkSpan
import org.json.JSONObject

/** Optional application metadata for selections containing a configured link. */
data class SelectionClipboardConfig(
  val linkTextByUrl: Map<String, String> = emptyMap(),
  val htmlAttributes: Map<String, String> = emptyMap(),
) {
  companion object {
    fun parse(value: String?): SelectionClipboardConfig =
      runCatching {
        val json = JSONObject(value ?: "")

        fun strings(key: String): Map<String, String> {
          val values = json.optJSONObject(key) ?: return emptyMap()
          return values
            .keys()
            .asSequence()
            .mapNotNull { name ->
              (values.opt(name) as? String)?.let { name to it }
            }.toMap()
        }
        SelectionClipboardConfig(strings("linkTextByUrl"), strings("htmlAttributes"))
      }.getOrDefault(SelectionClipboardConfig())
  }
}

internal fun canonicalClipboardText(
  text: Spanned,
  config: SelectionClipboardConfig,
): String? {
  val replacements =
    text
      .getSpans(0, text.length, LinkSpan::class.java)
      .mapNotNull { link ->
        config.linkTextByUrl[link.url]?.let { replacement ->
          Triple(text.getSpanStart(link).coerceAtLeast(0), text.getSpanEnd(link).coerceAtMost(text.length), replacement)
        }
      }.filter { it.second > it.first }
      .sortedByDescending { it.first }
  if (replacements.isEmpty()) return null
  return StringBuilder(text.toString())
    .apply {
      replacements.forEach { (start, end, replacement) -> replace(start, end, replacement) }
    }.toString()
}

internal fun clipboardHtml(
  html: String,
  config: SelectionClipboardConfig,
): String {
  fun escape(value: String) =
    value
      .replace("&", "&amp;")
      .replace("\"", "&quot;")
      .replace("<", "&lt;")
      .replace(">", "&gt;")
  val attributes =
    config.htmlAttributes
      .filterKeys { it.matches(Regex("[A-Za-z_][A-Za-z0-9:_-]*")) }
      .entries
      .joinToString(" ") { (name, value) -> "$name=\"${escape(value)}\"" }
  return if (attributes.isEmpty()) html else "<div $attributes>$html</div>"
}
