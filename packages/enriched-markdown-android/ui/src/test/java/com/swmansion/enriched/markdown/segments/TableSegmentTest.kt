@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.segments

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PluginSnapshot
import com.swmansion.enriched.markdown.spans.TaskListSpan
import com.swmansion.enriched.markdown.test.FakePlugin
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.defaultStyle
import com.swmansion.enriched.markdown.test.TestAstFactory.blockquote
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.emphasis
import com.swmansion.enriched.markdown.test.TestAstFactory.latexMathDisplay
import com.swmansion.enriched.markdown.test.TestAstFactory.latexMathInline
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.softBreak
import com.swmansion.enriched.markdown.test.TestAstFactory.table
import com.swmansion.enriched.markdown.test.TestAstFactory.tableBody
import com.swmansion.enriched.markdown.test.TestAstFactory.tableCell
import com.swmansion.enriched.markdown.test.TestAstFactory.tableHead
import com.swmansion.enriched.markdown.test.TestAstFactory.tableHeaderCell
import com.swmansion.enriched.markdown.test.TestAstFactory.tableRow
import com.swmansion.enriched.markdown.test.TestAstFactory.taskListItem
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import com.swmansion.enriched.markdown.utils.common.serialization.MarkdownASTSerializer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28, 35])
class TableSegmentTest {
  private val context: Context = ApplicationProvider.getApplicationContext()

  private fun simpleTable(headerText: String = "Header") =
    table(
      head = tableHead(tableRow(tableHeaderCell("default", text(headerText)))),
      body = tableBody(tableRow(tableCell("default", text("Cell")))),
    )

  // A. Splitting and rendering

  @Test
  fun splitProducesTextTableTextInDocumentOrder() {
    val tableNode = simpleTable()
    val doc = document(paragraph(text("Before")), tableNode, paragraph(text("After")))

    val segments = splitASTIntoSegments(doc)

    assertEquals(3, segments.size)
    assertTrue(segments[0] is MarkdownSegment.Text)
    assertTrue(segments[1] is MarkdownSegment.Table)
    assertTrue(segments[2] is MarkdownSegment.Text)
    assertEquals(tableNode, (segments[1] as MarkdownSegment.Table).node)
  }

  @Test
  fun consecutiveTablesWithTextBetweenProduceFiveSegments() {
    val doc =
      document(
        paragraph(text("Intro")),
        simpleTable("A"),
        paragraph(text("Between")),
        simpleTable("B"),
        paragraph(text("Outro")),
      )

    val segments = splitASTIntoSegments(doc)

    assertEquals(5, segments.size)
    assertTrue(segments[1] is MarkdownSegment.Table)
    assertTrue(segments[3] is MarkdownSegment.Table)
  }

  @Test
  fun adjacentTablesWithNoTextBetweenProduceNoEmptyTextSegment() {
    val doc = document(simpleTable("A"), simpleTable("B"))

    val segments = splitASTIntoSegments(doc)

    assertEquals(2, segments.size)
    assertTrue(segments.all { it is MarkdownSegment.Table })
  }

  /** Cells render with the segment, on the render thread, so a plugin's renderer in a cell never runs on the main thread. */
  @Test
  fun aTableSegmentArrivesWithItsCellsRenderedByTheInstalledPlugins() {
    val node =
      table(
        head = tableHead(tableRow(tableHeaderCell("default", text("Formula")))),
        body = tableBody(tableRow(tableCell("default", latexMathInline("x^2")))),
      )

    val rendered =
      MarkdownSegmentRenderer.render(
        listOf(MarkdownSegment.Table(node)),
        defaultStyle,
        context,
        onPluginEvent = {},
        plugins = PluginSnapshot.of(FakePlugin()),
      )

    val rows = (rendered.single() as RenderedSegment.Table).table.rows
    assertEquals("Formula", rows[0].single().attributedText.toString())
    assertEquals("[fake:x^2:sink=true]", rows[1].single().attributedText.toString())
  }

  @Test
  fun tableSignatureDiffersFromTextSignatureForTheSameNode() {
    val tableNode = simpleTable()
    val segments = MarkdownSegmentRenderer.render(listOf(MarkdownSegment.Table(tableNode)), defaultStyle, context)

    val tableSignature = (segments[0] as RenderedSegment.Table).signature
    val textKindSignature = SegmentSignature.signatureForNode(tableNode) xor SegmentSignature.TEXT_KIND_SALT

    assertNotEquals(textKindSignature, tableSignature)
  }

  @Test
  fun changingCellTextChangesSignatureButRerenderingSameDocumentDoesNot() {
    val original = MarkdownSegment.Table(simpleTable("Header"))
    val changed = MarkdownSegment.Table(simpleTable("Changed"))

    val originalSignature = (MarkdownSegmentRenderer.render(listOf(original), defaultStyle, context)[0] as RenderedSegment.Table).signature
    val changedSignature = (MarkdownSegmentRenderer.render(listOf(changed), defaultStyle, context)[0] as RenderedSegment.Table).signature
    val rerenderedSignature =
      (MarkdownSegmentRenderer.render(listOf(original), defaultStyle, context)[0] as RenderedSegment.Table).signature

    assertNotEquals(originalSignature, changedSignature)
    assertEquals(originalSignature, rerenderedSignature)
  }

  @Test
  fun taskIndicesStayDocumentGlobalAcrossATableSegment() {
    val firstList =
      MarkdownSegment.Text(
        listOf(
          unorderedList(
            taskListItem(checked = false, paragraph(text("First task"))),
            taskListItem(checked = false, paragraph(text("Second task"))),
          ),
        ),
      )
    val tableSegment = MarkdownSegment.Table(simpleTable())
    val secondList =
      MarkdownSegment.Text(
        listOf(
          unorderedList(
            taskListItem(checked = false, paragraph(text("Third task"))),
            taskListItem(checked = false, paragraph(text("Fourth task"))),
          ),
        ),
      )

    val rendered = MarkdownSegmentRenderer.render(listOf(firstList, tableSegment, secondList), defaultStyle, context)

    val firstText = (rendered[0] as RenderedSegment.Text).styledText
    val secondText = (rendered[2] as RenderedSegment.Text).styledText

    val firstIndices = firstText.getSpans(0, firstText.length, TaskListSpan::class.java).map { it.taskIndex }.sorted()
    val secondIndices = secondText.getSpans(0, secondText.length, TaskListSpan::class.java).map { it.taskIndex }.sorted()

    assertEquals(listOf(0, 1), firstIndices)
    assertEquals(listOf(2, 3), secondIndices)
  }

  // Only a root-level table becomes its own segment. A nested one stays in the text segment, where
  // the renderer has no entry for the structural table nodes - its cells are dropped for now. These
  // guard the split boundary; rendering them properly needs the nested block container work.
  @Test
  fun tableNestedInBlockquoteIsNotHoistedIntoItsOwnSegment() {
    val doc = document(blockquote(paragraph(text("Quoted")), simpleTable("Header text")))

    val segments = splitASTIntoSegments(doc)

    assertEquals(1, segments.size)
    assertTrue(segments[0] is MarkdownSegment.Text)
  }

  @Test
  fun tableNestedInListItemIsNotHoistedIntoItsOwnSegment() {
    val doc = document(unorderedList(listItem(paragraph(text("Item")), simpleTable("Header text"))))

    val segments = splitASTIntoSegments(doc)

    assertEquals(1, segments.size)
    assertTrue(segments[0] is MarkdownSegment.Text)
  }

  // C. Copy output

  @Test
  fun serializeTableRoundTripsToWellFormedGfmWithMixedAlignments() {
    val node =
      table(
        head =
          tableHead(
            tableRow(
              tableHeaderCell("default", text("A")),
              tableHeaderCell("center", text("B")),
              tableHeaderCell("right", text("C")),
            ),
          ),
        body =
          tableBody(
            tableRow(
              tableCell("default", text("1")),
              tableCell("center", text("2")),
              tableCell("right", text("3")),
            ),
          ),
      )

    val markdown = MarkdownASTSerializer.serializeTable(node)

    assertEquals(
      "| A | B | C |\n" +
        "| --- | :---: | ---: |\n" +
        "| 1 | 2 | 3 |\n",
      markdown,
    )
  }

  @Test
  fun serializeTableEmitsDelimiterRowForHeaderOnlyTable() {
    val node = table(head = tableHead(tableRow(tableHeaderCell("left", text("A")), tableHeaderCell("default", text("B")))))

    val markdown = MarkdownASTSerializer.serializeTable(node)

    assertEquals("| A | B |\n| :--- | --- |\n", markdown)
  }

  @Test
  fun serializeTableEscapesLiteralPipesInCells() {
    val node =
      table(
        head = tableHead(tableRow(tableHeaderCell("default", text("a|b")))),
        body = tableBody(tableRow(tableCell("default", text("c|d")))),
      )

    val markdown = MarkdownASTSerializer.serializeTable(node)

    assertTrue(markdown.contains("| a\\|b |"))
    assertTrue(markdown.contains("| c\\|d |"))
  }

  @Test
  fun serializeTableKeepsInlineEmphasisMarkers() {
    val node =
      table(
        head = tableHead(tableRow(tableHeaderCell("default", text("Header")))),
        body = tableBody(tableRow(tableCell("default", emphasis(text("italic"))))),
      )

    val markdown = MarkdownASTSerializer.serializeTable(node)

    assertTrue(markdown.contains("*italic*"))
  }

  @Test
  fun serializeTableKeepsLatexDelimiters() {
    val node =
      table(
        head = tableHead(tableRow(tableHeaderCell("default", text("Formula")))),
        body =
          tableBody(
            tableRow(tableCell("default", text("a "), latexMathInline("x^2"), text(" b"))),
            tableRow(tableCell("default", latexMathDisplay("\\frac{1}{2}"))),
          ),
      )

    val markdown = MarkdownASTSerializer.serializeTable(node)

    assertTrue(markdown.contains("| a \$x^2\$ b |"))
    assertTrue(markdown.contains("| \$\$\\frac{1}{2}\$\$ |"))
  }

  @Test
  fun serializeTableKeepsLatexSplitAcrossTextChildren() {
    val latex = MarkdownASTNode(NodeType.LatexMathInline, children = listOf(text("a +"), softBreak(), text("b")))
    val node =
      table(
        head = tableHead(tableRow(tableHeaderCell("default", text("Formula")))),
        body = tableBody(tableRow(tableCell("default", latex))),
      )

    val markdown = MarkdownASTSerializer.serializeTable(node)

    assertTrue(markdown.contains("| \$a + b\$ |"))
  }
}
