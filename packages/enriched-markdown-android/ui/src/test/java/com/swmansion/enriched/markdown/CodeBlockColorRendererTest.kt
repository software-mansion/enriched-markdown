package com.swmansion.enriched.markdown

import android.graphics.Color
import android.text.Spanned
import android.text.TextPaint
import android.text.style.CharacterStyle
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.defaultStyle
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.blockquote
import com.swmansion.enriched.markdown.test.TestAstFactory.code
import com.swmansion.enriched.markdown.test.TestAstFactory.codeBlock
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.link
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.orderedList
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.taskListItem
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * A code block's text color must survive the container it sits in: list spans are set after the
 * item's content, so they would otherwise repaint the code with the list color.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class CodeBlockColorRendererTest {
  private val codeBlockColor get() = defaultStyle.codeBlockStyle.color
  private val listColor get() = defaultStyle.listStyle.color

  @Test
  fun codeBlockInUnorderedListItemKeepsCodeBlockColor() {
    val rendered = render(document(unorderedList(listItem(paragraph(text("intro")), codeBlock("val x = 1")))))

    assertEquals(codeBlockColor, rendered.drawStateAt("val x = 1").color)
    assertEquals(listColor, rendered.drawStateAt("intro").color)
  }

  @Test
  fun codeBlockInOrderedListItemKeepsCodeBlockColor() {
    val rendered = render(document(orderedList(listItem(codeBlock("val x = 1")))))

    assertEquals(codeBlockColor, rendered.drawStateAt("val x = 1").color)
  }

  @Test
  fun codeBlockInNestedListItemKeepsCodeBlockColor() {
    val rendered =
      render(
        document(
          unorderedList(
            listItem(
              paragraph(text("outer")),
              unorderedList(listItem(codeBlock("val x = 1"))),
            ),
          ),
        ),
      )

    assertEquals(codeBlockColor, rendered.drawStateAt("val x = 1").color)
  }

  @Test
  fun codeBlockInTaskListItemKeepsCodeBlockColor() {
    val rendered = render(document(unorderedList(taskListItem(true, codeBlock("val x = 1")))))

    assertEquals(codeBlockColor, rendered.drawStateAt("val x = 1").color)
  }

  @Test
  fun codeBlockInBlockquoteKeepsCodeBlockColor() {
    val rendered = render(document(blockquote(codeBlock("val x = 1"))))

    assertEquals(codeBlockColor, rendered.drawStateAt("val x = 1").color)
  }

  @Test
  fun codeBlockInListItemInBlockquoteKeepsCodeBlockColor() {
    val rendered = render(document(blockquote(unorderedList(listItem(codeBlock("val x = 1"))))))

    assertEquals(codeBlockColor, rendered.drawStateAt("val x = 1").color)
  }

  @Test
  fun linkInListItemKeepsLinkColor() {
    val rendered = render(listItemDocument(text("see "), link("https://example.com", text("docs"))))

    assertEquals(defaultStyle.linkStyle.color, rendered.drawStateAt("docs").color)
    assertEquals(listColor, rendered.drawStateAt("see").color)
  }

  @Test
  fun inlineCodeInListItemKeepsCodeColor() {
    val rendered = render(listItemDocument(text("run "), code("make")))

    assertEquals(defaultStyle.codeStyle.color, rendered.drawStateAt("make").color)
  }

  private fun listItemDocument(vararg inlines: MarkdownASTNode) = document(unorderedList(listItem(paragraph(*inlines))))

  /** The paint a run is drawn with: every character style over it, applied in span order. */
  private fun Spanned.drawStateAt(run: String): TextPaint {
    val start = toString().indexOf(run)
    val paint = TextPaint().apply { color = Color.BLACK }
    getSpans(start, start + run.length, CharacterStyle::class.java).forEach { it.updateDrawState(paint) }
    return paint
  }
}
