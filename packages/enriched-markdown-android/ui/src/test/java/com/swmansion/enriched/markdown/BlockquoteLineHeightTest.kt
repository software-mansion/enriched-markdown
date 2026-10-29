package com.swmansion.enriched.markdown

import android.text.Layout
import android.text.SpannableString
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.MarkerCanvas
import com.swmansion.enriched.markdown.test.TestAstFactory.blockquote
import com.swmansion.enriched.markdown.test.TestAstFactory.codeBlock
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** A quote's line height applies to its own text, around nested quotes and code blocks. */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class BlockquoteLineHeightTest {
  @Test
  fun quoteLineHeightLeavesCodeBlockLinesAlone() {
    val quote =
      blockquote(
        paragraph(text("Intro")),
        codeBlock("first line\nlast line\n"),
        paragraph(text("Next")),
        paragraph(text("Last")),
      )
    val natural = layout(quote, quoteLineHeight = 0f)
    val tall = layout(quote, quoteLineHeight = TALL_LINE_HEIGHT)

    // The layout's first and last lines add their font's padding, so check one in between.
    assertEquals("the quote's own text takes the line height", TALL_LINE_HEIGHT.toInt(), tall.height("Next"))
    for (line in listOf("first line", "last line")) {
      assertEquals("height of \"$line\"", natural.height(line), tall.height(line))
    }
  }

  @Test
  fun quoteLineHeightCoversTextOnBothSidesOfANestedQuote() {
    val quote =
      blockquote(
        paragraph(text("Before")),
        blockquote(paragraph(text("Inner"))),
        paragraph(text("After")),
        paragraph(text("Last")),
      )
    val tall = layout(quote, quoteLineHeight = TALL_LINE_HEIGHT)

    for (line in listOf("Before", "After")) {
      assertEquals("height of \"$line\"", TALL_LINE_HEIGHT.toInt(), tall.height(line))
    }
  }

  private fun layout(
    quote: MarkdownASTNode,
    quoteLineHeight: Float,
  ): Rendered {
    val base = MarkdownRenderTestSupport.defaultStyle
    val style = MarkdownRenderTestSupport.styleWithBlockquote(base.blockquoteStyle.copy(lineHeight = quoteLineHeight))
    // A paragraph above the quote keeps its first line off the layout's top padding.
    val text = SpannableString(render(document(paragraph(text("Top")), quote), style))
    return Rendered(text, MarkerCanvas.layout(text, style.blockquoteStyle.fontSize))
  }

  private class Rendered(
    val text: CharSequence,
    val layout: Layout,
  ) {
    fun height(content: String): Int {
      val start = text.indexOf(content)
      require(start >= 0) { "Rendered text does not contain \"$content\": \"$text\"" }
      val line = layout.getLineForOffset(start)
      return layout.getLineBottom(line) - layout.getLineTop(line)
    }
  }

  private companion object {
    const val TALL_LINE_HEIGHT = 120f
  }
}
