package com.swmansion.enriched.markdown

import android.text.Layout
import android.text.SpannableString
import android.text.StaticLayout
import android.text.TextPaint
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

// Issue #1060: the shadow node measures the SpannableStringBuilder, which hands a
// line's LineHeightSpans to StaticLayout by start position, while the TextView
// draws a SpannableString copy, which hands them over in insertion order. A list's
// line height covers spacer lines its children added earlier, so the two layouts
// must still agree on a spacer's height, and that height must be the margin's.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ListSpacerLineHeightTest {
  @Test
  fun spacersInsideAListItemAreMeasuredAsTallAsTheyAreDrawn() {
    val measured = render(style(), quoteInsideListItem())
    val drawn = SpannableString(measured)

    assertEquals(layout(measured).height, layout(drawn).height)
  }

  @Test
  fun spacersInsideAListItemKeepTheirOwnHeight() {
    val text = render(style(), quoteInsideListItem())
    for (copy in listOf(text, SpannableString(text))) {
      // The quote's top padding spacer, then its bottom margin spacer.
      assertEquals(copy.javaClass.simpleName, listOf(QUOTE_PADDING, QUOTE_MARGIN), spacerHeights(layout(copy)))
    }
  }

  private fun style() =
    styleConfig(
      list = mapOf("lineHeight" to LIST_LINE_HEIGHT.toDouble()),
      blockquote = mapOf("marginBottom" to QUOTE_MARGIN.toDouble(), "padding" to QUOTE_PADDING.toDouble()),
    )

  // A quote followed by more text in the same item: its padding and bottom-margin
  // spacers sit inside the list's line-height range.
  private fun quoteInsideListItem() =
    unorderedList(
      listItem(
        paragraph(text("before")),
        MarkdownASTNode(NodeType.Blockquote, children = listOf(paragraph(text("quote")))),
        paragraph(text("after")),
      ),
      listItem(paragraph(text("last"))),
    )

  private fun layout(text: CharSequence): Layout = StaticLayout.Builder.obtain(text, 0, text.length, TextPaint(), 400).build()

  // Heights of the lone "\n" lines: the spacers that block padding and margins insert.
  private fun spacerHeights(layout: Layout): List<Int> =
    (0 until layout.lineCount)
      .filter { line ->
        val start = layout.getLineStart(line)
        layout.getLineEnd(line) - start == 1 && layout.text[start] == '\n'
      }.map { layout.getLineBottom(it) - layout.getLineTop(it) }

  private companion object {
    const val LIST_LINE_HEIGHT = 40
    const val QUOTE_MARGIN = 8
    const val QUOTE_PADDING = 6
  }
}
