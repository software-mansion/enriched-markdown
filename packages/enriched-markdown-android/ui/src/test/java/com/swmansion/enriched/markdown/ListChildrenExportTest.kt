package com.swmansion.enriched.markdown

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.core.view.accessibility.AccessibilityNodeInfoCompat
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.test.HTMLAssertions.assertContainsHtmlInOrder
import com.swmansion.enriched.markdown.test.HTMLGeneratorTestSupport.generateHTML
import com.swmansion.enriched.markdown.test.MarkdownExtractorTestSupport.extractFromFullSelection
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.blockquote
import com.swmansion.enriched.markdown.test.TestAstFactory.codeBlock
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.orderedList
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.taskListItem
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/** Copy-as-markdown, HTML and accessibility output for list items whose spans are split around code blocks. */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class ListChildrenExportTest {
  private val context = ApplicationProvider.getApplicationContext<Context>()

  @Test
  fun nestsACodeBlockThatEndsAnItemUnderTheItem() {
    val markdown =
      extractFromFullSelection(
        document(
          unorderedList(
            listItem(paragraph(text("Item")), codeBlock("first line\nlast line\n")),
            listItem(paragraph(text("Next"))),
          ),
        ),
      )

    assertEquals("- Item\n  ```\n  first line\n  last line\n  ```\n- Next", markdown)
  }

  @Test
  fun putsTheMarkerOfAnItemThatOpensWithACodeBlockOnItsFence() {
    val markdown =
      extractFromFullSelection(
        document(
          unorderedList(
            listItem(codeBlock("val x = 1\n"), paragraph(text("After code"))),
            listItem(paragraph(text("Next"))),
          ),
        ),
      )

    assertEquals("- ```\n  val x = 1\n  ```\n  After code\n- Next", markdown)
  }

  @Test
  fun continuesAnItemAfterItsCodeBlock() {
    val markdown = extractFromFullSelection(codeMidItem())

    assertEquals("1. Item\n   ```\n   val x = 1\n   ```\n   After code\n2. Next", markdown)
  }

  @Test
  fun nestsACodeBlockUnderTheInnermostItem() {
    val markdown =
      extractFromFullSelection(
        document(
          unorderedList(
            listItem(paragraph(text("Outer")), unorderedList(listItem(paragraph(text("Inner")), codeBlock("val x = 1\n")))),
            listItem(paragraph(text("Next"))),
          ),
        ),
      )

    assertEquals("- Outer\n  - Inner\n    ```\n    val x = 1\n    ```\n- Next", markdown)
  }

  @Test
  fun leavesNoEmptyListItemsAroundCodeBlocksInHtml() {
    for (document in listOf(codeMidItem(), codeEndingQuotedItem())) {
      val html = generateHTML(render(document))

      assertFalse("Empty list item in $html", Regex("<li[^>]*></li>").containsMatchIn(html))
      assertFalse("Empty paragraph in $html", Regex("<p[^>]*></p>").containsMatchIn(html))
    }
    val html = generateHTML(render(codeMidItem()))
    html.assertContainsHtmlInOrder("Item</li>", "<pre", "val x = 1", "</pre>", "After code</li>", "Next</li>")
  }

  @Test
  fun keepsConsecutiveCodeBlocksApartInHtml() {
    val documents =
      listOf(
        document(unorderedList(listItem(paragraph(text("Item")), codeBlock("one\n"), codeBlock("two\n")))),
        document(unorderedList(listItem(paragraph(text("Item")), codeBlock("one\n")), listItem(codeBlock("two\n")))),
        document(blockquote(codeBlock("one\n"), codeBlock("two\n"))),
      )
    for (document in documents) {
      val html = generateHTML(render(document))

      html.assertContainsHtmlInOrder("<pre", "one", "</pre>", "<pre", "two", "</pre>")
      assertFalse("Empty list item in $html", Regex("<li[^>]*></li>").containsMatchIn(html))
      assertFalse("Empty paragraph in $html", Regex("<p[^>]*></p>").containsMatchIn(html))
    }
  }

  @Test
  fun keepsTheQuoteOfAQuoteThatOpensWithCodeInHtml() {
    val html = generateHTML(render(document(blockquote(codeBlock("one\n")), paragraph(text("Outside")))))

    html.assertContainsHtmlInOrder("<blockquote", "</blockquote>", "Outside")
  }

  @Test
  fun announcesOnlyTheLineThatDrawsAnItemsMarkerAsAListItem() {
    val roles = accessibilityRoles(codeMidItem())

    assertEquals("list item 1", roles["Item"])
    assertEquals("The code block is not a list item of its own", null, roles["val x = 1"])
    assertEquals("Text after the code block continues the item", null, roles["After code"])
    assertEquals("list item 2", roles["Next"])
  }

  private fun codeMidItem(): MarkdownASTNode =
    document(
      orderedList(
        listItem(paragraph(text("Item")), codeBlock("val x = 1\n"), paragraph(text("After code"))),
        listItem(paragraph(text("Next"))),
      ),
    )

  private fun codeEndingQuotedItem(): MarkdownASTNode =
    document(
      unorderedList(
        listItem(paragraph(text("Bullet")), blockquote(codeBlock("first line\nlast line\n"))),
        listItem(paragraph(text("Another bullet"))),
      ),
    )

  /** Each accessibility item's text mapped to the role it announces, `null` for plain text. */
  private fun accessibilityRoles(document: MarkdownASTNode): Map<String, String?> {
    val view = EnrichedMarkdownInternalText(context).apply { setText(render(document), TextView.BufferType.SPANNABLE) }
    view.layoutParams = ViewGroup.LayoutParams(VIEW_WIDTH, ViewGroup.LayoutParams.WRAP_CONTENT)
    view.measure(
      View.MeasureSpec.makeMeasureSpec(VIEW_WIDTH, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    view.layout(0, 0, view.measuredWidth, view.measuredHeight)

    val provider = view.accessibilityHelper.getAccessibilityNodeProvider(view)!!
    val host = provider.createAccessibilityNodeInfo(View.NO_ID)!!
    return (0 until host.childCount).associate { id ->
      val node: AccessibilityNodeInfoCompat = provider.createAccessibilityNodeInfo(id)!!
      node.text.toString() to node.roleDescription?.toString()
    }
  }

  private companion object {
    const val VIEW_WIDTH = 600
  }
}
