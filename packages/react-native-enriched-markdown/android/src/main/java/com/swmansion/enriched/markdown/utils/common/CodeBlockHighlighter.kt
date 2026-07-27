package com.swmansion.enriched.markdown.utils.common

import android.text.Spanned
import com.swmansion.enriched.markdown.styles.CodeBlockStyle

/**
 * Seam for the optional syntax highlighting module.
 *
 * The main package never depends on a highlighter at compile time. An optional
 * module (planned: a tree-sitter based implementation gated the same way as the
 * math module) provides IMPLEMENTATION_CLASS, which is resolved lazily via
 * reflection, mirroring how MathContainerView is loaded in EnrichedMarkdown.
 * When the class is absent, or highlight() returns null (unknown language,
 * highlight failure), callers fall back to plain uncolored rendering, so a
 * missing module degrades to exactly the current code block appearance.
 *
 * Implementations must only attach spans that do not affect text metrics
 * (foreground color, style-preserving spans). CodeBlockContainerView measures
 * block height from the plain text, so any metric-affecting span would make
 * the measured height diverge from the drawn height.
 */
interface CodeBlockHighlighter {
  fun highlight(
    code: String,
    language: String?,
    style: CodeBlockStyle,
  ): Spanned?
}

object CodeBlockHighlighting {
  private const val IMPLEMENTATION_CLASS = "com.swmansion.enriched.markdown.codehighlight.CodeBlockHighlighterImpl"

  val highlighter: CodeBlockHighlighter? by lazy {
    try {
      Class
        .forName(IMPLEMENTATION_CLASS)
        .getDeclaredConstructor()
        .newInstance() as? CodeBlockHighlighter
    } catch (_: Exception) {
      null
    }
  }
}
