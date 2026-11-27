package com.swmansion.enriched.markdown.input

import com.swmansion.enriched.markdown.input.model.StyleType
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class InlineStyleStateTest {
  // onChangeState for a selection follows the formatting a toggle leaves behind (#1208).
  @Test
  fun togglingAStyleOnASelectionReportsTheNewState() {
    for (style in listOf(StyleType.BOLD, StyleType.ITALIC, StyleType.UNDERLINE, StyleType.STRIKETHROUGH, StyleType.SPOILER)) {
      val view = EnrichedMarkdownTextInputView(RuntimeEnvironment.getApplication())
      view.text!!.insert(0, "Hello")
      view.setSelection(0, 5)

      view.toggleInlineStyle(style)
      assertEquals("$style on", true, view.eventEmitter.lastEmittedStyleState[style])
      view.toggleInlineStyle(style)
      assertEquals("$style off", false, view.eventEmitter.lastEmittedStyleState[style])
    }
  }
}
