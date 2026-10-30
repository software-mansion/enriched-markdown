package com.swmansion.enriched.markdown.input

import com.swmansion.enriched.markdown.input.editing.ZWSP
import com.swmansion.enriched.markdown.input.formatting.MarkdownSerializer
import com.swmansion.enriched.markdown.input.model.StyleType
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class ListItemReturnTest {
  private val view = EnrichedMarkdownTextInputView(RuntimeEnvironment.getApplication())

  private fun type(text: String) {
    for (char in text) {
      view.text!!.insert(view.selectionStart, char.toString())
    }
  }

  // Each line with its block's Markdown prefix. Unlike the serializer, this keeps
  // empty items, so an inserted item shows up as a bare marker.
  private fun lines(): List<String> {
    val text = view.text.toString()
    var lineStart = 0
    return text.split('\n').map { line ->
      val block = view.blockStore.blockStartingAt(lineStart)
      val prefix = block?.let { view.formatter.handlerForBlock(it.type)?.markdownLinePrefix(it) } ?: ""
      lineStart += line.length + 1
      prefix + line.replace(ZWSP.toString(), "")
    }
  }

  private fun markdown(): String =
    MarkdownSerializer.serialize(
      view.text.toString(),
      view.allFormattingRangesForSerialization(),
      view.blockStore.allRanges,
    ) { block -> view.formatter.handlerForBlock(block.type)?.markdownLinePrefix(block) ?: "" }

  private fun lineAt(index: Int): String = view.text.toString().split('\n')[index]

  private fun returnBefore(word: String) {
    view.setSelection(view.text.toString().indexOf(word))
    type("\n")
  }

  @Test
  fun insertsAnEmptyBulletAboveWhenReturnIsPressedAtTheStartOfAnItem() {
    view.toggleUnorderedList()
    type("apples\nbananas")

    returnBefore("bananas")

    assertEquals(listOf("- apples", "- ", "- bananas"), lines())
    assertEquals(view.text.toString().indexOf("bananas"), view.selectionStart)
  }

  @Test
  fun keepsOrderedNumberingWhenReturnIsPressedAtTheStartOfAnItem() {
    view.toggleOrderedList()
    type("apples\nbananas")

    returnBefore("bananas")

    assertEquals(listOf("1. apples", "2. ", "3. bananas"), lines())
  }

  @Test
  fun insertsAnEmptyItemAboveTheFirstItem() {
    view.toggleUnorderedList()
    type("apples\nbananas")

    returnBefore("apples")

    assertEquals(listOf("- ", "- apples", "- bananas"), lines())
    assertEquals(view.text.toString().indexOf("apples"), view.selectionStart)
  }

  @Test
  fun anchorsTheInsertedEmptyItemSoItsMarkerDraws() {
    view.toggleUnorderedList()
    type("apples\nbananas")

    returnBefore("bananas")

    assertEquals(ZWSP.toString(), lineAt(1))
  }

  @Test
  fun dropsTheAnchorOnceTheInsertedItemGetsText() {
    view.toggleUnorderedList()
    type("apples\nbananas")
    returnBefore("bananas")

    view.setSelection(view.text.toString().indexOf(ZWSP) + 1)
    type("cherries")

    assertEquals(listOf("- apples", "- cherries", "- bananas"), lines())
    assertEquals("cherries", lineAt(1))
  }

  @Test
  fun keepsBothHalvesListedWhenAnItemIsSplitInTheMiddle() {
    view.toggleUnorderedList()
    type("apples\nbananas")

    returnBefore("nanas")

    assertEquals(listOf("- apples", "- ba", "- nanas"), lines())
  }

  @Test
  fun stillExitsTheListOnReturnInAnEmptyItem() {
    view.toggleUnorderedList()
    type("apples\n\n")

    assertEquals(listOf("- apples", ""), lines())
  }

  @Test
  fun exitsTheListOnReturnBeforeTheAnchorOfAnEmptyItem() {
    view.toggleUnorderedList()
    type("apples\n")

    view.setSelection(view.text.toString().indexOf(ZWSP))
    type("\n")

    assertEquals(listOf("- apples", ""), lines())
    assertEquals("apples\n", view.text.toString())
  }

  @Test
  fun insertsTwoAnchoredItemsOnTwoReturnsAtTheStartOfAnItem() {
    view.toggleUnorderedList()
    type("apples\nbananas")

    returnBefore("bananas")
    type("\n")

    assertEquals(listOf("- apples", "- ", "- ", "- bananas"), lines())
    assertEquals(ZWSP.toString(), lineAt(1))
    assertEquals(ZWSP.toString(), lineAt(2))
  }

  @Test
  fun keepsTheNestingLevelOnTheInsertedItem() {
    view.toggleUnorderedList()
    type("apples\nbananas")
    view.indentList()

    returnBefore("bananas")

    assertEquals(listOf(0, 1, 1), view.blockStore.allRanges.map { it.level })
  }

  @Test
  fun keepsTheItemsInlineStyleOffTheInsertedItem() {
    view.toggleUnorderedList()
    type("apples\n")
    view.toggleInlineStyle(StyleType.BOLD)
    type("bananas")
    view.toggleInlineStyle(StyleType.BOLD)

    returnBefore("bananas")
    view.setSelection(view.text.toString().indexOf(ZWSP) + 1)
    type("cherries")

    assertEquals("- apples\n- cherries\n- **bananas**", markdown())
  }

  @Test
  fun keepsAFollowingNestedItemNestedOnReturnAtTheEndOfANestedItem() {
    view.toggleUnorderedList()
    type("apples\nbananas")
    view.indentList()
    type("\ncherries")

    view.setSelection(view.text.toString().indexOf("bananas") + "bananas".length)
    type("\n")

    assertEquals(listOf(0, 1, 1, 1), view.blockStore.allRanges.map { it.level })
  }
}
