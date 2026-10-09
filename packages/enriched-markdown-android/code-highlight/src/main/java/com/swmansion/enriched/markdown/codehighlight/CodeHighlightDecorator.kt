@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.codehighlight

import android.content.Context
import android.text.SpannableStringBuilder
import android.text.Spanned
import com.swmansion.enriched.markdown.plugin.CodeBlockDecorator
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.styles.StyleConfig

/**
 * Colors a code block's tokens with one [SyntaxTokenSpan] each. Holds nothing but the shared
 * [SyntaxTokenCache], so render workers can run it concurrently.
 */
internal class CodeHighlightDecorator(
  private val tokens: SyntaxTokenCache,
) : CodeBlockDecorator {
  override fun decorate(
    builder: SpannableStringBuilder,
    start: Int,
    end: Int,
    language: String?,
    style: StyleConfig,
    context: Context,
  ) {
    if (language == null || end <= start) return

    val code = builder.subSequence(start, end).toString()
    val triplets = tokens.tokens(code, language)
    if (triplets.isEmpty()) return

    val colors = style.codeHighlightStyle()
    for (i in 0 until triplets.size - 2 step 3) {
      val tokenStart = triplets[i]
      val tokenEnd = triplets[i + 1]
      val type = TOKEN_TYPES.getOrNull(triplets[i + 2]) ?: continue
      val color = colors[type] ?: continue
      // The seam already clamps to the code; this guards a mismatched cache entry or source.
      if (tokenStart < 0 || tokenEnd > code.length || tokenStart >= tokenEnd) continue

      builder.setSpan(SyntaxTokenSpan(type, color), start + tokenStart, start + tokenEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }
  }

  private companion object {
    val TOKEN_TYPES = SyntaxTokenType.entries
  }
}
