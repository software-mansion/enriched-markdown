package com.swmansion.enriched.markdown.test

import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.utils.text.conversion.MarkdownExtractor

object MarkdownExtractorTestSupport {
  fun extractFromSelection(
    document: MarkdownASTNode,
    selectionStart: Int,
    selectionEnd: Int,
  ): String? {
    val textView =
      MarkdownTextViewTestSupport.createTextViewWithSelection(
        document,
        selectionStart,
        selectionEnd,
      )
    return MarkdownExtractor.getMarkdownForSelection(textView)
  }

  fun extractFromFullSelection(document: MarkdownASTNode): String? {
    val textView = MarkdownTextViewTestSupport.createTextViewWithFullSelection(document)
    return MarkdownExtractor.getMarkdownForSelection(textView)
  }

  fun extractSelectingText(
    document: MarkdownASTNode,
    selectedText: String,
  ): String? {
    val textView = MarkdownTextViewTestSupport.createTextViewSelectingText(document, selectedText)
    return MarkdownExtractor.getMarkdownForSelection(textView)
  }
}
