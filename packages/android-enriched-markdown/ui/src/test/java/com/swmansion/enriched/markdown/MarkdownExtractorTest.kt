package com.swmansion.enriched.markdown

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.test.MarkdownExtractorTestSupport.extractFromFullSelection
import com.swmansion.enriched.markdown.test.MarkdownExtractorTestSupport.extractSelectingText
import com.swmansion.enriched.markdown.test.MarkdownTextViewTestSupport.createEnrichedMarkdownTextWithStoredMarkdown
import com.swmansion.enriched.markdown.test.MarkdownTextViewTestSupport.createTextViewSelectingText
import com.swmansion.enriched.markdown.test.MarkdownTextViewTestSupport.createTextViewWithFullSelection
import com.swmansion.enriched.markdown.test.MarkdownTextViewTestSupport.createTextViewWithSelection
import com.swmansion.enriched.markdown.test.MarkdownTextViewTestSupport.indexOf
import com.swmansion.enriched.markdown.test.MarkdownTextViewTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.blockquote
import com.swmansion.enriched.markdown.test.TestAstFactory.code
import com.swmansion.enriched.markdown.test.TestAstFactory.codeBlock
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.emphasis
import com.swmansion.enriched.markdown.test.TestAstFactory.heading
import com.swmansion.enriched.markdown.test.TestAstFactory.image
import com.swmansion.enriched.markdown.test.TestAstFactory.link
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.orderedList
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.strikethrough
import com.swmansion.enriched.markdown.test.TestAstFactory.strong
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.thematicBreak
import com.swmansion.enriched.markdown.test.TestAstFactory.underline
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import com.swmansion.enriched.markdown.utils.text.conversion.MarkdownExtractor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class MarkdownExtractorTest {
  @Test
  fun returnsNullForInvalidSelection() {
    val spannable = render(document(paragraph(text("Hello"))))
    val textView = createTextViewWithSelection(spannable, 2, 2)

    assertNull(MarkdownExtractor.getMarkdownForSelection(textView))
  }

  @Test
  fun fullSelectionOnEnrichedMarkdownTextReturnsOriginalMarkdown() {
    val original = "# Title\n\n with *bold**."
    val rendered =
      render(
        document(
          heading(1, text("Title")),
          paragraph(
            text("Paragraph with "),
            strong(text("bold")),
            text("."),
          ),
        ),
      )

    val textView = createEnrichedMarkdownTextWithStoredMarkdown(original, rendered)

    assertEquals(original, MarkdownExtractor.getMarkdownForSelection(textView))
  }

  @Test
  fun extractsPlainParagraphText() {
    val markdown =
      extractSelectingText(
        document(paragraph(text("Hello CommonMark"))),
        "Hello CommonMark",
      )

    assertEquals("Hello CommonMark", markdown)
  }

  @Test
  fun extractsBoldText() {
    assertEquals(
      "**31%**",
      extractSelectingText(
        document(
          paragraph(
            text("Forests cover "),
            strong(text("31%")),
            text(" of land."),
          ),
        ),
        "31%",
      ),
    )
  }

  @Test
  fun extractsStrikethroughText() {
    assertEquals(
      "~~31%~~",
      extractSelectingText(
        document(
          paragraph(
            text("Forests cover "),
            strikethrough(text("31%")),
            text(" of land."),
          ),
        ),
        "31%",
      ),
    )
  }

  @Test
  fun extractsUnderlinedTextAsHtmlTag() {
    assertEquals(
      "<u>31%</u>",
      extractSelectingText(
        document(
          paragraph(
            text("Forests cover "),
            underline(text("31%")),
            text(" of land."),
          ),
        ),
        "31%",
      ),
    )
  }

  @Test
  fun extractsStrikethroughAndUnderlinedTextWithUnderlineInnermost() {
    assertEquals(
      "~~<u>31%</u>~~",
      extractSelectingText(
        document(
          paragraph(
            text("Forests cover "),
            strikethrough(underline(text("31%"))),
            text(" of land."),
          ),
        ),
        "31%",
      ),
    )
  }

  @Test
  fun extractsItalicText() {
    assertEquals(
      "*300 million years*",
      extractSelectingText(
        document(
          paragraph(
            text("Over "),
            emphasis(text("300 million years")),
            text(" old."),
          ),
        ),
        "300 million years",
      ),
    )
  }

  @Test
  fun extractsBoldAndItalicInSameParagraph() {
    val spannable =
      render(
        document(
          paragraph(
            text("Text with "),
            strong(text("bold")),
            text(" and "),
            emphasis(text("italic")),
            text(" styles."),
          ),
        ),
      )
    val start = indexOf(spannable, "Text with ")
    val end = spannable.indexOf(" styles.") + " styles.".length
    val textView = createTextViewWithSelection(spannable, start, end)

    assertEquals(
      "Text with **bold** and *italic* styles.",
      MarkdownExtractor.getMarkdownForSelection(textView),
    )
  }

  @Test
  fun extractsInlineCode() {
    assertEquals(
      "`48 pounds`",
      extractSelectingText(
        document(
          paragraph(
            text("Use "),
            code("48 pounds"),
            text(" per year."),
          ),
        ),
        "48 pounds",
      ),
    )
  }

  @Test
  fun extractsLink() {
    assertEquals(
      "[Example link](https://example.com)",
      extractSelectingText(
        document(
          paragraph(
            link("https://example.com", text("Example link")),
          ),
        ),
        "Example link",
      ),
    )
  }

  @Test
  fun extractsHeading() {
    assertEquals(
      "# The Hidden World of Forest Ecosystems\n",
      extractSelectingText(
        document(
          heading(1, text("The Hidden World of Forest Ecosystems")),
        ),
        "The Hidden World of Forest Ecosystems",
      ),
    )
  }

  @Test
  fun extractsAllHeadingLevels() {
    for (level in 1..6) {
      val title = "Heading level $level"
      val expected = "${"#".repeat(level)} $title\n"
      assertEquals(
        expected,
        extractSelectingText(document(heading(level, text(title))), title),
      )
    }
  }

  @Test
  fun extractsBlockquote() {
    val quote = "In every walk with nature, one receives far more than he seeks."
    assertEquals(
      "> $quote",
      extractSelectingText(
        document(
          blockquote(
            paragraph(text(quote)),
          ),
        ),
        quote,
      ),
    )
  }

  @Test
  fun extractsNestedBlockquote() {
    val innerQuote = "Inner quote"
    val spannable =
      render(
        document(
          blockquote(
            paragraph(text("Outer quote")),
            blockquote(
              paragraph(text(innerQuote)),
            ),
          ),
        ),
      )
    val start = indexOf(spannable, innerQuote)
    val textView = createTextViewWithSelection(spannable, start, start + innerQuote.length)

    assertEquals("> > $innerQuote", MarkdownExtractor.getMarkdownForSelection(textView))
  }

  @Test
  fun extractsUnorderedListItem() {
    assertEquals(
      "- Climate regulation",
      extractSelectingText(
        document(
          unorderedList(
            listItem(paragraph(text("Climate regulation"))),
            listItem(paragraph(text("Biodiversity"))),
          ),
        ),
        "Climate regulation",
      ),
    )
  }

  @Test
  fun extractsOrderedListItem() {
    assertEquals(
      "1. First item",
      extractSelectingText(
        document(
          orderedList(
            listItem(paragraph(text("First item"))),
            listItem(paragraph(text("Second item"))),
          ),
        ),
        "First item",
      ),
    )
  }

  @Test
  fun extractsSecondOrderedListItem() {
    assertEquals(
      "2. Second item",
      extractSelectingText(
        document(
          orderedList(
            listItem(paragraph(text("First item"))),
            listItem(paragraph(text("Second item"))),
          ),
        ),
        "Second item",
      ),
    )
  }

  @Test
  fun extractsNestedUnorderedListItem() {
    val nestedItem = "Nested item"
    val spannable =
      render(
        document(
          unorderedList(
            listItem(
              paragraph(text("Parent item")),
              unorderedList(
                listItem(paragraph(text(nestedItem))),
              ),
            ),
          ),
        ),
      )
    val start = indexOf(spannable, nestedItem)
    val textView = createTextViewWithSelection(spannable, start, start + nestedItem.length)

    assertEquals("  - $nestedItem", MarkdownExtractor.getMarkdownForSelection(textView))
  }

  @Test
  fun extractsMultiLineCodeBlock() {
    val codeBlockContent =
      """
      fun main() {
        println("forest")
      }
      """.trimIndent()
    val spannable = render(document(codeBlock(codeBlockContent)))
    val codeBlockSpan =
      spannable
        .getSpans(0, spannable.length, com.swmansion.enriched.markdown.spans.CodeBlockSpan::class.java)
        .first()
    val textView =
      createTextViewWithSelection(
        spannable,
        spannable.getSpanStart(codeBlockSpan),
        spannable.getSpanEnd(codeBlockSpan),
      )

    assertEquals("```\n$codeBlockContent", MarkdownExtractor.getMarkdownForSelection(textView))
  }

  @Test
  fun extractsCodeBlockWithoutClosingFenceWhenSelectionExcludesTrailingNewline() {
    val code = "fun main() = println(\"forest\")"
    val spannable = render(document(codeBlock(code)))
    val codeBlockSpan =
      spannable
        .getSpans(0, spannable.length, com.swmansion.enriched.markdown.spans.CodeBlockSpan::class.java)
        .first()
    val start = spannable.getSpanStart(codeBlockSpan)
    val end = spannable.getSpanEnd(codeBlockSpan)
    val textView = createTextViewWithSelection(spannable, start, end)

    assertEquals("```\n$code", MarkdownExtractor.getMarkdownForSelection(textView))
  }

  @Test
  fun extractsThematicBreak() {
    val spannable = render(document(thematicBreak()))
    val breakStart =
      spannable
        .getSpans(0, spannable.length, com.swmansion.enriched.markdown.spans.ThematicBreakSpan::class.java)
        .first()
        .let { spannable.getSpanStart(it) }
    val breakEnd = breakStart + 1
    val textView = createTextViewWithSelection(spannable, breakStart, breakEnd)

    assertEquals("---\n", MarkdownExtractor.getMarkdownForSelection(textView))
  }

  @Test
  fun extractsInlineImage() {
    val url = "https://example.com/forest.jpg"
    val spannable =
      render(
        document(
          paragraph(
            text("Before "),
            image(url),
            text(" after"),
          ),
        ),
      )
    val imageStart = spannable.indexOf('\uFFFC')
    val textView = createTextViewWithSelection(spannable, imageStart, imageStart + 1)

    assertEquals("![image]($url)", MarkdownExtractor.getMarkdownForSelection(textView))
  }

  @Test
  fun extractsBlockImage() {
    val url = "https://example.com/forest.jpg"
    val spannable =
      render(
        document(
          paragraph(
            image(url),
          ),
        ),
      )
    val imageStart = spannable.indexOf('\uFFFC')
    val textView = createTextViewWithSelection(spannable, imageStart, imageStart + 1)

    assertEquals("![image]($url)\n", MarkdownExtractor.getMarkdownForSelection(textView))
  }

  @Test
  fun extractsParagraphWithInlineImageAndText() {
    val url = "https://example.com/forest.jpg"
    val spannable =
      render(
        document(
          paragraph(
            text("See "),
            image(url),
            text(" for details."),
          ),
        ),
      )
    val textView = createTextViewWithFullSelection(spannable)

    assertEquals(
      "See ![image]($url) for details.",
      MarkdownExtractor.getMarkdownForSelection(textView),
    )
  }

  @Test
  fun extractsMultipleListItemsFromFullSelection() {
    val markdown =
      extractFromFullSelection(
        document(
          unorderedList(
            listItem(paragraph(text("Alpha"))),
            listItem(paragraph(text("Beta"))),
          ),
        ),
      )

    assertEquals("- Alpha\n- Beta", markdown)
  }

  @Test
  fun extractsBlockquoteWithFormattedText() {
    val spannable =
      render(
        document(
          blockquote(
            paragraph(
              text("Quote with "),
              strong(text("bold")),
              text(" text."),
            ),
          ),
        ),
      )
    val start = indexOf(spannable, "Quote with ")
    val end = spannable.indexOf(" text.") + " text.".length
    val textView = createTextViewWithSelection(spannable, start, end)

    assertEquals("> Quote with **bold** text.", MarkdownExtractor.getMarkdownForSelection(textView))
  }

  @Test
  fun extractsPartialSelectionWithinParagraph() {
    val spannable = render(document(paragraph(text("Hello world"))))
    val textView = createTextViewWithSelection(spannable, 0, 5)

    assertEquals("Hello", MarkdownExtractor.getMarkdownForSelection(textView))
  }

  @Test
  fun extractsLinkWithinBoldContext() {
    assertEquals(
      "[link text](https://example.com)",
      extractSelectingText(
        document(
          paragraph(
            link("https://example.com", text("link text")),
          ),
        ),
        "link text",
      ),
    )
  }
}
