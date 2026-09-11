package com.swmansion.enriched.markdown.segments

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.spans.TaskListSpan
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.defaultStyle
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.blockquote
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.heading
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.taskListItem
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28, 35])
class MarkdownSegmentRendererTest {
  private val context: Context = ApplicationProvider.getApplicationContext()

  @Test
  fun splitASTIntoSegmentsCollapsesTableFreeDocumentIntoOneTextSegment() {
    val doc =
      document(
        heading(1, text("Title")),
        paragraph(text("First paragraph")),
        paragraph(text("Second paragraph")),
        unorderedList(taskListItem(checked = false, paragraph(text("Item")))),
        blockquote(paragraph(text("Quoted"))),
      )

    val segments = splitASTIntoSegments(doc)

    assertEquals(1, segments.size)
    val textSegment = segments[0] as MarkdownSegment.Text
    assertEquals(doc.children, textSegment.nodes)
  }

  @Test
  fun taskIndicesStayDocumentGlobalAcrossSegments() {
    val firstSegment =
      MarkdownSegment.Text(
        listOf(
          unorderedList(
            taskListItem(checked = false, paragraph(text("First task"))),
            taskListItem(checked = false, paragraph(text("Second task"))),
          ),
        ),
      )
    val secondSegment =
      MarkdownSegment.Text(
        listOf(
          unorderedList(
            taskListItem(checked = false, paragraph(text("Third task"))),
            taskListItem(checked = false, paragraph(text("Fourth task"))),
          ),
        ),
      )

    val rendered = MarkdownSegmentRenderer.render(listOf(firstSegment, secondSegment), defaultStyle, context)

    val firstText = (rendered[0] as RenderedSegment.Text).styledText
    val secondText = (rendered[1] as RenderedSegment.Text).styledText

    val firstIndices = firstText.getSpans(0, firstText.length, TaskListSpan::class.java).map { it.taskIndex }.sorted()
    val secondIndices = secondText.getSpans(0, secondText.length, TaskListSpan::class.java).map { it.taskIndex }.sorted()

    assertEquals(listOf(0, 1), firstIndices)
    assertEquals(listOf(2, 3), secondIndices)
  }

  @Test
  fun singleSegmentRenderIsUnchanged() {
    val doc =
      document(
        heading(1, text("Title")),
        paragraph(text("A paragraph with content")),
      )
    val segment = MarkdownSegment.Text(doc.children)

    val rendered = MarkdownSegmentRenderer.render(listOf(segment), defaultStyle, context)
    val renderedText = (rendered[0] as RenderedSegment.Text).styledText

    assertEquals(render(doc).toString(), renderedText.toString())
  }
}
