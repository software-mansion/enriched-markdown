package com.swmansion.enriched.markdown.input

import com.swmansion.enriched.markdown.input.editing.ZWSP
import com.swmansion.enriched.markdown.input.formatting.InputParser
import com.swmansion.enriched.markdown.input.formatting.MarkdownSerializer
import com.swmansion.enriched.markdown.input.model.BlockRange
import com.swmansion.enriched.markdown.input.model.BlockType
import com.swmansion.enriched.markdown.input.model.FormattingRange
import com.swmansion.enriched.markdown.input.model.StyleType
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

// The conversion itself is tested once in the core (packages/core/cpp/tests); these cover
// what the Kotlin wrappers add: the JNI boundary and the empty-line ZWSP anchor.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class InputMarkdownWrapperTest {
  private val view = EnrichedMarkdownTextInputView(RuntimeEnvironment.getApplication())

  @Test
  fun keepsUtf16OffsetsAcrossTheBoundary() {
    val markdown = "😀 **漢字** [link](https://example.com)"
    val parsed = InputParser.parseToPlainTextAndRanges(markdown)

    assertEquals("😀 漢字 link", parsed.plainText)
    assertEquals(
      listOf(Triple(StyleType.BOLD, 3, 5), Triple(StyleType.LINK, 6, 10)),
      parsed.formattingRanges.map { Triple(it.type, it.start, it.end) },
    )
    assertEquals("https://example.com", parsed.formattingRanges[1].url)
    assertEquals(markdown, MarkdownSerializer.serialize(parsed.plainText, parsed.formattingRanges, parsed.blockRanges))
  }

  @Test
  fun escapesPlainTextThatWouldReadAsMarkup() {
    for (markdown in listOf("2 \\*x\\* 6", "- \\> x", "## Use \\#")) {
      val parsed = InputParser.parseToPlainTextAndRanges(markdown)
      assertEquals(markdown, MarkdownSerializer.serialize(parsed.plainText, parsed.formattingRanges, parsed.blockRanges))
    }
  }

  @Test
  fun keepsTheBlocksAfterAnUnclosedLinkDelimiter() {
    val parsed = InputParser.parseToPlainTextAndRanges("## Title [wip\n\nBody")

    assertEquals("Title [wip\n\nBody", parsed.plainText)
    assertEquals(listOf(BlockType.HEADING_2), parsed.blockRanges.map { it.type })
  }

  @Test
  fun anchorsAnImportedEmptyListItemAwayFromTheCaret() {
    val parsed = InputParser.parseToPlainTextAndRanges("- a\n- \n- c")

    assertEquals("a\n${ZWSP}\nc", parsed.plainText)
    assertEquals(
      listOf(Triple(0, 1, 0), Triple(2, 3, 0), Triple(4, 5, 0)),
      parsed.blockRanges.map { Triple(it.start, it.end, it.level) },
    )
  }

  @Test
  fun shiftsRangesAfterASeededAnchor() {
    val parsed = InputParser.parseToPlainTextAndRanges("1. a\n2. \n3. **c**")

    assertEquals("a\n${ZWSP}\nc", parsed.plainText)
    assertEquals(listOf(Triple(StyleType.BOLD, 4, 5)), parsed.formattingRanges.map { Triple(it.type, it.start, it.end) })
    assertEquals(listOf(1, 2, 3), parsed.blockRanges.map { it.ordinal })
  }

  @Test
  fun stripsTheAnchorAndShiftsRangesBeforeExporting() {
    val text = "a\n${ZWSP}\nc"
    val blocks =
      listOf(
        BlockRange(BlockType.UNORDERED_LIST_ITEM, 0, 1),
        BlockRange(BlockType.UNORDERED_LIST_ITEM, 2, 3),
        BlockRange(BlockType.UNORDERED_LIST_ITEM, 4, 5),
      )
    val ranges = listOf(FormattingRange(StyleType.BOLD, 4, 5))

    assertEquals("- a\n- \n- **c**", MarkdownSerializer.serialize(text, ranges, blocks))
  }

  @Test
  fun roundTripsAnEmptyItemThroughTheView() {
    view.setValueFromJS("- a\n- \n- c")

    assertEquals("a\n${ZWSP}\nc", view.text.toString())
    assertEquals(
      "- a\n- \n- c",
      MarkdownSerializer.serialize(view.text.toString(), view.allFormattingRangesForSerialization(), view.blockStore.allRanges),
    )
  }

  @Test
  fun dropsTheAnchorOnceAnImportedEmptyItemGetsText() {
    view.setValueFromJS("- a\n- \n- c")
    view.setSelection(view.text.toString().indexOf(ZWSP) + 1)
    view.text!!.insert(view.selectionStart, "b")

    assertEquals("a\nb\nc", view.text.toString())
  }

  @Test
  fun keepsTheOrdinalsOfCopiedItems() {
    view.setValueFromJS("1. a\n2. b\n3. c\n4. d")
    val text = view.text.toString()
    val start = text.indexOf("c")

    view.setSelection(start, text.length)

    assertEquals("3. c\n4. d", view.markdownForSelectedRange())
  }
}
