package com.swmansion.enriched.markdown.input

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
class EmptyListAnchorFormattingTest {
  private val view = EnrichedMarkdownTextInputView(RuntimeEnvironment.getApplication())

  private fun type(text: String) {
    for (char in text) {
      view.text!!.insert(view.selectionStart, char.toString())
    }
  }

  private fun markdown(): String =
    MarkdownSerializer.serialize(
      view.text.toString(),
      view.allFormattingRangesForSerialization(),
      view.blockStore.allRanges,
    ) { block -> view.formatter.handlerForBlock(block.type)?.markdownLinePrefix(block) ?: "" }

  @Test
  fun keepsAnInlineStyleOnTheTextTypedIntoANewBulletItem() {
    type("Intro\n")
    view.toggleUnorderedList()

    view.toggleInlineStyle(StyleType.ITALIC)
    type("ital")
    view.toggleInlineStyle(StyleType.ITALIC)
    type(" plain")

    assertEquals("Intro\n- *ital* plain", markdown())
  }

  @Test
  fun leavesPlainTextTypedIntoTheNextBulletItemUnstyled() {
    type("Intro\n")
    view.toggleUnorderedList()
    view.toggleInlineStyle(StyleType.ITALIC)
    type("ital")
    view.toggleInlineStyle(StyleType.ITALIC)
    type(" plain\nnext")

    assertEquals("Intro\n- *ital* plain\n- next", markdown())
  }

  @Test
  fun keepsAnInlineStyleOnTheTextTypedIntoANewOrderedItem() {
    view.toggleOrderedList()

    view.toggleInlineStyle(StyleType.BOLD)
    type("bold")

    assertEquals("1. **bold**", markdown())
  }
}
