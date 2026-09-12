package com.swmansion.enriched.markdown

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.test.HTMLAssertions.assertContainsHtml
import com.swmansion.enriched.markdown.test.HTMLAssertions.assertContainsHtmlInOrder
import com.swmansion.enriched.markdown.test.HTMLGeneratorTestSupport.generateHTML
import com.swmansion.enriched.markdown.test.HTMLGeneratorTestSupport.generateHTMLSelectingText
import com.swmansion.enriched.markdown.test.MarkdownTextViewTestSupport.createTextViewWithSelection
import com.swmansion.enriched.markdown.test.MarkdownTextViewTestSupport.indexOf
import com.swmansion.enriched.markdown.test.MarkdownTextViewTestSupport.render
import com.swmansion.enriched.markdown.test.MarkdownTextViewTestSupport.selectedRange
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
import com.swmansion.enriched.markdown.test.TestAstFactory.underline
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class HTMLGeneratorTest {
  @Test
  fun returnsEmptyHtmlDocumentForEmptySelection() {
    assertEquals("<html></html>", generateHTML("".toSpannable()))
  }

  @Test
  fun generatesPlainParagraph() {
    val html = generateHTMLSelectingText(document(paragraph(text("Hello CommonMark"))), "Hello CommonMark")

    html.assertContainsHtml("<html>")
    html.assertContainsHtmlInOrder("<p", "Hello CommonMark", "</p>", "</html>")
  }

  @Test
  fun generatesBoldText() {
    val html =
      generateHTMLSelectingText(
        document(
          paragraph(
            text("Forests cover "),
            strong(text("31%")),
            text(" of land."),
          ),
        ),
        "31%",
      )

    html.assertContainsHtmlInOrder("<strong", "31%", "</strong>")
  }

  @Test
  fun generatesStrikethroughText() {
    val html =
      generateHTMLSelectingText(
        document(
          paragraph(
            text("Forests cover "),
            strikethrough(text("31%")),
            text(" of land."),
          ),
        ),
        "31%",
      )

    html.assertContainsHtmlInOrder("<s", "31%", "</s>")
  }

  @Test
  fun generatesUnderlinedText() {
    val html =
      generateHTMLSelectingText(
        document(
          paragraph(
            text("Forests cover "),
            underline(text("31%")),
            text(" of land."),
          ),
        ),
        "31%",
      )

    html.assertContainsHtmlInOrder("<u", "31%", "</u>")
  }

  @Test
  fun generatesItalicText() {
    val html =
      generateHTMLSelectingText(
        document(
          paragraph(
            text("Over "),
            emphasis(text("300 million years")),
            text(" old."),
          ),
        ),
        "300 million years",
      )

    html.assertContainsHtmlInOrder("<em", "300 million years", "</em>")
  }

  @Test
  fun generatesBoldAndItalicInSameParagraph() {
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
    val html = generateHTML(selectedRange(spannable, start, end))

    html.assertContainsHtmlInOrder("<strong", "bold", "</strong>", "<em", "italic", "</em>")
  }

  @Test
  fun generatesInlineCode() {
    val html =
      generateHTMLSelectingText(
        document(
          paragraph(
            text("Use "),
            code("48 pounds"),
            text(" per year."),
          ),
        ),
        "48 pounds",
      )

    html.assertContainsHtmlInOrder("<code", "48 pounds", "</code>")
  }

  @Test
  fun generatesLink() {
    val html =
      generateHTMLSelectingText(
        document(
          paragraph(
            link("https://example.com", text("Example link")),
          ),
        ),
        "Example link",
      )

    html.assertContainsHtmlInOrder(
      "<a href=\"https://example.com\"",
      "Example link",
      "</a>",
    )
  }

  @Test
  fun generatesHeading() {
    val html =
      generateHTMLSelectingText(
        document(
          heading(1, text("The Hidden World of Forest Ecosystems")),
        ),
        "The Hidden World of Forest Ecosystems",
      )

    html.assertContainsHtmlInOrder(
      "<h1",
      "The Hidden World of Forest Ecosystems",
      "</h1>",
    )
  }

  @Test
  fun generatesAllHeadingLevels() {
    for (level in 1..6) {
      val title = "Heading level $level"
      val html = generateHTMLSelectingText(document(heading(level, text(title))), title)

      html.assertContainsHtmlInOrder("<h$level", title, "</h$level>")
    }
  }

  @Test
  fun generatesBlockquote() {
    val quote = "In every walk with nature, one receives far more than he seeks."
    val html =
      generateHTMLSelectingText(
        document(
          blockquote(
            paragraph(text(quote)),
          ),
        ),
        quote,
      )

    html.assertContainsHtmlInOrder("<blockquote", quote, "</blockquote>")
  }

  @Test
  fun generatesNestedBlockquote() {
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
    val html = generateHTML(selectedRange(spannable, start, start + innerQuote.length))

    html.assertContainsHtmlInOrder("<blockquote", innerQuote, "</blockquote>")
  }

  @Test
  fun generatesUnorderedListItem() {
    val html =
      generateHTMLSelectingText(
        document(
          unorderedList(
            listItem(paragraph(text("Climate regulation"))),
            listItem(paragraph(text("Biodiversity"))),
          ),
        ),
        "Climate regulation",
      )

    html.assertContainsHtmlInOrder("<ul", "<li", "Climate regulation", "</li>", "</ul>")
  }

  @Test
  fun generatesOrderedListItem() {
    val html =
      generateHTMLSelectingText(
        document(
          orderedList(
            listItem(paragraph(text("First item"))),
            listItem(paragraph(text("Second item"))),
          ),
        ),
        "First item",
      )

    html.assertContainsHtmlInOrder("<ol", "<li", "First item", "</li>", "</ol>")
  }

  @Test
  fun generatesNestedUnorderedListItem() {
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
    val html = generateHTML(selectedRange(spannable, start, start + nestedItem.length))

    html.assertContainsHtmlInOrder("<ul", "<li", nestedItem, "</li>", "</ul>")
  }

  @Test
  fun generatesCodeBlock() {
    val codeBlockContent =
      """
      fun main() {
        println("forest")
      }
      """.trimIndent()
    val spannable = render(document(codeBlock(codeBlockContent)))
    val html = generateHTML(spannable)

    html.assertContainsHtmlInOrder("<pre", "<code", "fun main()", "println", "forest", "</code>", "</pre>")
  }

  @Test
  fun generatesInlineImage() {
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
    val html = generateHTML(selectedRange(spannable, imageStart, imageStart + 1))

    html.assertContainsHtml("<img src=\"$url\"")
  }

  @Test
  fun generatesBlockImage() {
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
    val html = generateHTML(selectedRange(spannable, imageStart, imageStart + 1))

    html.assertContainsHtml("<img src=\"$url\"")
    html.assertContainsHtml("max-width: 100%")
  }

  @Test
  fun generatesParagraphWithInlineImageAndText() {
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
    val html = generateHTML(spannable)

    html.assertContainsHtmlInOrder("See ", "<img src=\"$url\"", " for details.")
  }

  @Test
  fun generatesMultipleListItemsFromFullSelection() {
    val spannable =
      render(
        document(
          unorderedList(
            listItem(paragraph(text("Alpha"))),
            listItem(paragraph(text("Beta"))),
          ),
        ),
      )
    val html = generateHTML(spannable)

    html.assertContainsHtmlInOrder("<ul", "<li", "Alpha", "</li>", "<li", "Beta", "</li>", "</ul>")
  }

  @Test
  fun generatesBlockquoteWithFormattedText() {
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
    val html = generateHTML(selectedRange(spannable, start, end))

    html.assertContainsHtmlInOrder("<blockquote", "<strong", "bold", "</strong>", "</blockquote>")
  }

  @Test
  fun escapesHtmlSpecialCharacters() {
    val html =
      generateHTMLSelectingText(
        document(paragraph(text("Tom & Jerry <3"))),
        "Tom & Jerry <3",
      )

    html.assertContainsHtml("Tom &amp; Jerry &lt;3")
  }

  @Test
  fun generatesPartialSelectionWithinParagraph() {
    val spannable = render(document(paragraph(text("Hello world"))))
    val textView = createTextViewWithSelection(spannable, 0, 5)
    val html = generateHTML(textView.text.subSequence(textView.selectionStart, textView.selectionEnd) as android.text.Spannable)

    html.assertContainsHtmlInOrder("<p", "Hello", "</p>")
  }

  private fun String.toSpannable() = android.text.SpannableString(this)
}
