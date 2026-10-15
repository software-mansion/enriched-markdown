package com.swmansion.enriched.markdown

import com.swmansion.enriched.markdown.parser.Md4cFlags

/**
 * The optional Markdown syntax a view recognises on top of CommonMark and GitHub tables, task lists
 * and strikethrough.
 */
data class MarkdownOptions(
  /** `_text_` and `__text__` underline instead of emphasising. */
  val underline: Boolean = false,
  /** `^text^` raises above the baseline. */
  val superscript: Boolean = false,
  /** `~text~` lowers below the baseline. */
  val subscript: Boolean = false,
  /** `==text==` gets a highlight background. */
  val highlight: Boolean = false,
  /** Bare URLs, `www.` links and e-mail addresses become links. */
  val permissiveAutolinks: Boolean = true,
  /** Every line break inside a paragraph is kept rather than joined into one line. */
  val hardSoftBreaks: Boolean = false,
  /** Each blank line renders as an empty line instead of collapsing into one paragraph break. */
  val preserveBlankLines: Boolean = false,
  /** `> [!NOTE]` and the other GitHub alert blockquotes render as admonitions. */
  val admonitions: Boolean = false,
) {
  /** What the parser runs with before plugins add the syntax they render. */
  internal fun toParserFlags(): Md4cFlags =
    Md4cFlags(
      underline = underline,
      latexMath = false, // math is enabled via LatexMathPlugin
      superscript = superscript,
      subscript = subscript,
      highlight = highlight,
      permissiveAutolinks = permissiveAutolinks,
      hardSoftBreaks = hardSoftBreaks,
      preserveBlankLines = preserveBlankLines,
      admonitions = admonitions,
    )

  companion object {
    val Default = MarkdownOptions()
  }
}
