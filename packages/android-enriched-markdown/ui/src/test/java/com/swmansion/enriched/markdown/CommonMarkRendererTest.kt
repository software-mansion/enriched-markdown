package com.swmansion.enriched.markdown

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.spans.BlockquoteSpan
import com.swmansion.enriched.markdown.spans.CodeBlockSpan
import com.swmansion.enriched.markdown.spans.CodeSpan
import com.swmansion.enriched.markdown.spans.EmphasisSpan
import com.swmansion.enriched.markdown.spans.HeadingSpan
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.spans.OrderedListSpan
import com.swmansion.enriched.markdown.spans.StrongSpan
import com.swmansion.enriched.markdown.spans.ThematicBreakSpan
import com.swmansion.enriched.markdown.spans.UnorderedListSpan
import com.swmansion.enriched.markdown.test.MarkdownRenderAssertions.assertContains
import com.swmansion.enriched.markdown.test.MarkdownRenderAssertions.assertHasSpan
import com.swmansion.enriched.markdown.test.MarkdownRenderAssertions.assertLinkUrl
import com.swmansion.enriched.markdown.test.MarkdownRenderAssertions.assertSpanCovers
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.blockquote
import com.swmansion.enriched.markdown.test.TestAstFactory.code
import com.swmansion.enriched.markdown.test.TestAstFactory.codeBlock
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.emphasis
import com.swmansion.enriched.markdown.test.TestAstFactory.heading
import com.swmansion.enriched.markdown.test.TestAstFactory.image
import com.swmansion.enriched.markdown.test.TestAstFactory.lineBreak
import com.swmansion.enriched.markdown.test.TestAstFactory.link
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.orderedList
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.softBreak
import com.swmansion.enriched.markdown.test.TestAstFactory.strong
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.thematicBreak
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class CommonMarkRendererTest {
  @Test
  fun rendersPlainParagraph() {
    val rendered = render(document(paragraph(text("Hello CommonMark"))))

    rendered.assertContains("Hello CommonMark")
  }

  @Test
  fun rendersSoftBreakAsSpace() {
    val rendered =
      render(
        document(
          paragraph(
            text("tracking your"),
            softBreak(),
            text("blood sugar"),
          ),
        ),
      )

    rendered.assertContains("tracking your blood sugar")
  }

  @Test
  fun rendersHardBreakAsNewline() {
    val rendered =
      render(
        document(
          paragraph(
            text("line one"),
            lineBreak(),
            text("line two"),
          ),
        ),
      )

    rendered.assertContains("line one\nline two")
  }

  @Test
  fun rendersBoldText() {
    val rendered =
      render(
        document(
          paragraph(
            text("Forests cover "),
            strong(text("31%")),
            text(" of land."),
          ),
        ),
      )

    rendered.assertContains("31%")
    rendered.assertSpanCovers("31%", StrongSpan::class.java)
  }

  @Test
  fun rendersItalicText() {
    val rendered =
      render(
        document(
          paragraph(
            text("Over "),
            emphasis(text("300 million years")),
            text(" old."),
          ),
        ),
      )

    rendered.assertContains("300 million years")
    rendered.assertSpanCovers("300 million years", EmphasisSpan::class.java)
  }

  @Test
  fun rendersHeading() {
    val rendered =
      render(
        document(
          heading(1, text("The Hidden World of Forest Ecosystems")),
        ),
      )

    rendered.assertContains("The Hidden World of Forest Ecosystems")
    rendered.assertSpanCovers("The Hidden World of Forest Ecosystems", HeadingSpan::class.java)
  }

  @Test
  fun rendersLink() {
    val rendered =
      render(
        document(
          paragraph(
            link("https://example.com", text("Example link")),
          ),
        ),
      )

    rendered.assertContains("Example link")
    rendered.assertSpanCovers("Example link", com.swmansion.enriched.markdown.spans.LinkSpan::class.java)
    rendered.assertLinkUrl("https://example.com")
  }

  @Test
  fun rendersInlineCode() {
    val rendered =
      render(
        document(
          paragraph(
            text("Use "),
            code("48 pounds"),
            text(" per year."),
          ),
        ),
      )

    rendered.assertContains("48 pounds")
    rendered.assertSpanCovers("48 pounds", CodeSpan::class.java)
  }

  @Test
  fun rendersBlockquote() {
    val rendered =
      render(
        document(
          blockquote(
            paragraph(text("In every walk with nature, one receives far more than he seeks.")),
          ),
        ),
      )

    rendered.assertContains("In every walk with nature")
    rendered.assertHasSpan(BlockquoteSpan::class.java)
  }

  @Test
  fun rendersUnorderedList() {
    val rendered =
      render(
        document(
          unorderedList(
            listItem(paragraph(text("Climate regulation"))),
            listItem(paragraph(text("Biodiversity"))),
          ),
        ),
      )

    rendered.assertContains("Climate regulation")
    rendered.assertContains("Biodiversity")
    rendered.assertHasSpan(UnorderedListSpan::class.java)
  }

  @Test
  fun rendersOrderedList() {
    val rendered =
      render(
        document(
          orderedList(
            listItem(paragraph(text("First item"))),
            listItem(paragraph(text("Second item"))),
          ),
        ),
      )

    rendered.assertContains("First item")
    rendered.assertContains("Second item")
    rendered.assertHasSpan(OrderedListSpan::class.java)
  }

  @Test
  fun rendersCodeBlock() {
    val rendered =
      render(
        document(
          codeBlock("fun main() = println(\"forest\")"),
        ),
      )

    rendered.assertContains("fun main()")
    rendered.assertHasSpan(CodeBlockSpan::class.java)
  }

  @Test
  fun rendersThematicBreak() {
    val rendered = render(document(thematicBreak()))

    rendered.assertHasSpan(ThematicBreakSpan::class.java)
  }

  @Test
  fun rendersImage() {
    val rendered =
      render(
        document(
          paragraph(
            image("https://example.com/forest.jpg", alt = "Forest"),
          ),
        ),
      )

    val images = rendered.getSpans(0, rendered.length, ImageSpan::class.java)
    assertTrue("Expected ImageSpan", images.isNotEmpty())
    assertEquals("https://example.com/forest.jpg", images.first().imageUrl)
  }

  @Test
  fun rendersMixedInlineStyles() {
    val rendered =
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

    rendered.assertContains("bold")
    rendered.assertContains("italic")
    rendered.assertSpanCovers("bold", StrongSpan::class.java)
    rendered.assertSpanCovers("italic", EmphasisSpan::class.java)
  }
}
