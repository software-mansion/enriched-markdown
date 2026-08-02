package com.swmansion.enriched.markdown.utils.common

import android.graphics.Color
import android.text.Spannable
import android.text.style.ForegroundColorSpan
import android.util.Log
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE

/**
 * Mirror of HighlightTokenType in cpp/highlight/CodeBlockHighlighter.hpp.
 * Values cross the JNI boundary as ordinals, the same way
 * MarkdownASTNode.NodeType does; keep the declaration order in sync.
 */
enum class HighlightTokenType {
  Keyword,
  Operator,
  Punctuation,
  String,
  Number,
  Constant,
  Comment,
  Function,
  Type,
  Variable,
  Property,
  Tag,
  Attribute,
  Embedded,
}

/**
 * Platform adapter over the shared C++ syntax highlighting seam
 * (core/cpp/highlight/CodeBlockHighlighter.hpp).
 *
 * The native call returns semantic tokens as (start, end, type) int triplets
 * with UTF-16 offsets into the code string, or null when highlighting is
 * unavailable (module compiled out, unknown language, parse failure). The
 * adapter applies token colors in place as ForegroundColorSpans onto the
 * plain styled code, so highlighting can never change text metrics and the
 * measured block height stays valid. When highlighting is unavailable the
 * spannable is left untouched and renders as plain text.
 */
object CodeBlockHighlighter {
  init {
    try {
      System.loadLibrary("react_codegen_EnrichedMarkdownTextSpec")
    } catch (e: UnsatisfiedLinkError) {
      Log.e("CodeBlockHighlighter", "Failed to load native library", e)
    }
  }

  private external fun nativeHighlightCode(
    code: String,
    language: String,
  ): IntArray?

  fun highlight(
    plainCode: Spannable,
    code: String,
    language: String?,
  ) {
    val tokens =
      try {
        nativeHighlightCode(code, language.orEmpty())
      } catch (e: UnsatisfiedLinkError) {
        null
      } ?: return

    var i = 0
    while (i + 2 < tokens.size) {
      val start = tokens[i]
      val end = tokens[i + 1]
      val color = HighlightTokenType.entries.getOrNull(tokens[i + 2])?.let(::colorForToken)
      if (color != null && start >= 0 && end > start && end <= plainCode.length) {
        plainCode.setSpan(ForegroundColorSpan(color), start, end, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
      }
      i += 3
    }
  }

  // TODO: provisional palette (GitHub light scheme); replace with themable
  // per-token colors on CodeBlockStyle when the highlighting module lands.
  private fun colorForToken(type: HighlightTokenType): Int? =
    when (type) {
      HighlightTokenType.Keyword -> Color.parseColor("#CF222E")
      HighlightTokenType.String -> Color.parseColor("#0A3069")
      HighlightTokenType.Number -> Color.parseColor("#0550AE")
      HighlightTokenType.Constant -> Color.parseColor("#0550AE")
      HighlightTokenType.Comment -> Color.parseColor("#6E7781")
      HighlightTokenType.Function -> Color.parseColor("#8250DF")
      HighlightTokenType.Type -> Color.parseColor("#953800")
      HighlightTokenType.Property -> Color.parseColor("#0550AE")
      HighlightTokenType.Tag -> Color.parseColor("#116329")
      HighlightTokenType.Attribute -> Color.parseColor("#0550AE")
      else -> null
    }
}
