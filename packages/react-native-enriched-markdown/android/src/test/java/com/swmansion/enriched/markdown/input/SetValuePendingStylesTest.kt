package com.swmansion.enriched.markdown.input

import com.swmansion.enriched.markdown.input.formatting.MarkdownSerializer
import com.swmansion.enriched.markdown.input.model.StyleType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

// A chat input sends by calling setValue(""): what was pending at the old caret must not style
// the next message.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class SetValuePendingStylesTest {
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

  private fun isActive(style: StyleType): Boolean = view.eventEmitter.isStyleEffectivelyActive(style)

  @Test
  fun clearingDropsAnUnderlinePendingAtTheCaret() {
    type("hello")
    view.setSelection(3)
    view.toggleInlineStyle(StyleType.UNDERLINE)
    assertTrue(isActive(StyleType.UNDERLINE))

    view.setValueFromCommand("")
    assertFalse(isActive(StyleType.UNDERLINE))
    type("next")
    assertEquals("next", markdown())
  }

  @Test
  fun clearingDropsABoldPendingAtTheCaret() {
    type("hello")
    view.toggleInlineStyle(StyleType.BOLD)
    assertTrue(isActive(StyleType.BOLD))

    view.setValueFromCommand("")
    assertFalse(isActive(StyleType.BOLD))
    type("next")
    assertEquals("next", markdown())
  }
}
