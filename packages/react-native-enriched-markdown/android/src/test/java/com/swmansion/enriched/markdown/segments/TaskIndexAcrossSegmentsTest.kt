package com.swmansion.enriched.markdown.segments

import android.text.Spanned
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.spans.TaskListSpan
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.taskListItem
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import com.swmansion.enriched.markdown.utils.text.interaction.TaskListToggleUtils
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * The task toggle rewrites the Nth task of the whole markdown source, so the
 * indices on the task spans must count across every segment in document order,
 * not restart in each text segment or blockquote.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class TaskIndexAcrossSegmentsTest {
  private val context = RuntimeEnvironment.getApplication()
  private val style by lazy { styleConfig() }

  @Test
  fun rendererNumbersTasksFromTheStartingIndex() {
    val renderer = Renderer().apply { configure(style, context) }

    val text = renderer.renderContent(listOf(tasks("a", "b")), startingTaskIndex = 5)

    assertEquals(listOf(5, 6), taskIndices(text))
    assertEquals(7, renderer.getTaskItemCount())
  }

  @Test
  fun taskIndicesContinueAcrossTablesCodeBlocksAndBlockquotes() {
    val quote =
      MarkdownASTNode(
        NodeType.Blockquote,
        children = listOf(tasks("q1"), codeBlock(), tasks("q2")),
      )
    val document =
      document(
        tasks("first", "second"),
        table(),
        tasks("third"),
        codeBlock(),
        quote,
        tasks("last"),
      )

    val rendered = render(document)

    assertEquals(listOf(0, 1), taskIndices(rendered[0]))
    assertEquals(listOf(2), taskIndices(rendered[2]))
    val renderedQuote = rendered[4] as RenderedSegment.Blockquote
    assertEquals(3, renderedQuote.taskIndexOffset)
    assertEquals(listOf(5), taskIndices(rendered[5]))

    // The quote renders its own children when its view applies the node, from its offset.
    val quoteChildren =
      MarkdownSegmentRenderer.render(
        splitASTIntoSegments(quote),
        style,
        context,
        null,
        null,
        style.blockquoteStyle,
        startingTaskIndex = renderedQuote.taskIndexOffset,
      )
    assertEquals(listOf(3), taskIndices(quoteChildren[0]))
    assertEquals(listOf(4), taskIndices(quoteChildren[2]))
  }

  @Test
  fun aSegmentWithTasksIsResignedWhenEarlierTasksChange() {
    val before = render(document(tasks("first"), table(), tasks("third"), paragraph(text("no tasks"))))
    val after = render(document(tasks("first", "new"), table(), tasks("third"), paragraph(text("no tasks"))))

    // Same content, new first index: its view must not be reused with stale indices.
    assertNotEquals(before[2].signature, after[2].signature)
    assertEquals(listOf(2), taskIndices(after[2]))

    val quote = MarkdownASTNode(NodeType.Blockquote, children = listOf(tasks("q")))
    val quoteBefore = render(document(tasks("first"), quote))[1]
    val quoteAfter = render(document(tasks("first", "new"), quote))[1]
    assertNotEquals(quoteBefore.signature, quoteAfter.signature)
  }

  @Test
  fun aSegmentWithoutTasksKeepsItsSignatureWhenEarlierTasksChange() {
    val before = render(document(tasks("first"), table(), paragraph(text("no tasks"))))
    val after = render(document(tasks("first", "new"), table(), paragraph(text("no tasks"))))

    assertEquals(before[1].signature, after[1].signature)
    assertEquals(before[2].signature, after[2].signature)
  }

  @Test
  fun toggleAtIndexCountsTasksInQuotesAndOrderedListsInDocumentOrder() {
    val markdown =
      """
      - [ ] first
      - [ ] second

      | a | b |
      |---|---|
      | 1 | 2 |

      1. [ ] third

      > - [ ] fourth
      > > * [ ] fifth

      + [ ] sixth
      """.trimIndent()

    val toggled = (0..5).map { TaskListToggleUtils.toggleAtIndex(markdown, it, true) }

    listOf("first", "second", "third", "fourth", "fifth", "sixth").forEachIndexed { index, item ->
      val changedLine =
        toggled[index]
          .lines()
          .zip(markdown.lines())
          .single { (new, old) -> new != old }
          .first
      assertEquals("index $index", true, changedLine.endsWith("[x] $item"))
    }
    assertEquals(markdown, TaskListToggleUtils.toggleAtIndex(markdown, 6, true))
  }

  private fun render(document: MarkdownASTNode): List<RenderedSegment> =
    MarkdownSegmentRenderer.render(splitASTIntoSegments(document), style, context, null, null)

  private fun taskIndices(segment: RenderedSegment): List<Int> = taskIndices((segment as RenderedSegment.Text).styledText)

  private fun taskIndices(text: Spanned): List<Int> =
    text
      .getSpans(0, text.length, TaskListSpan::class.java)
      .sortedBy { text.getSpanStart(it) }
      .map { it.taskIndex }

  private fun tasks(vararg items: String): MarkdownASTNode =
    unorderedList(*items.map { taskListItem(checked = false, paragraph(text(it))) }.toTypedArray())

  private fun table(): MarkdownASTNode = MarkdownASTNode(NodeType.Table)

  private fun codeBlock(): MarkdownASTNode = MarkdownASTNode(NodeType.CodeBlock, children = listOf(text("const x = 1;\n")))

  private fun document(vararg blocks: MarkdownASTNode): MarkdownASTNode = MarkdownASTNode(NodeType.Document, children = blocks.toList())
}
