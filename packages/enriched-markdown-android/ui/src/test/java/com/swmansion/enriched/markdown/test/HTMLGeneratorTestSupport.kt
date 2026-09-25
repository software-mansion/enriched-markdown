package com.swmansion.enriched.markdown.test

import android.content.Context
import android.text.Spannable
import androidx.test.core.app.ApplicationProvider
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.text.conversion.HTMLGenerator

object HTMLGeneratorTestSupport {
  private val context: Context = ApplicationProvider.getApplicationContext()

  val defaultStyle: StyleConfig = StyleConfig.default(context)

  fun generateHTML(
    spannable: Spannable,
    style: StyleConfig = defaultStyle,
  ): String {
    val metrics = context.resources.displayMetrics
    return HTMLGenerator.generateHTML(
      text = spannable,
      style = style,
      scaledDensity = metrics.scaledDensity,
      density = metrics.density,
      isRTL = false,
    )
  }

  fun generateHTML(
    spannable: Spannable,
    selectionStart: Int,
    selectionEnd: Int,
  ): String =
    generateHTML(
      MarkdownTextViewTestSupport.selectedRange(spannable, selectionStart, selectionEnd),
    )

  fun generateHTMLSelectingText(
    document: MarkdownASTNode,
    selectedText: String,
    style: StyleConfig = defaultStyle,
  ): String {
    val spannable = MarkdownTextViewTestSupport.render(document)
    val start = MarkdownTextViewTestSupport.indexOf(spannable, selectedText)
    return generateHTML(
      MarkdownTextViewTestSupport.selectedRange(spannable, start, start + selectedText.length),
      style,
    )
  }
}

object HTMLAssertions {
  fun String.assertContainsHtml(expected: String) {
    org.junit.Assert.assertTrue(
      "Expected HTML to contain \"$expected\" but was: $this",
      contains(expected),
    )
  }

  fun String.assertContainsHtmlInOrder(vararg parts: String) {
    var searchFrom = 0
    for (part in parts) {
      val index = indexOf(part, searchFrom)
      org.junit.Assert.assertTrue(
        "Expected HTML to contain \"$part\" after index $searchFrom but was: $this",
        index >= searchFrom,
      )
      searchFrom = index + part.length
    }
  }
}
