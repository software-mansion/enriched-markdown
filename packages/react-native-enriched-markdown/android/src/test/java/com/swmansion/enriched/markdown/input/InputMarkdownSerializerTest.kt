package com.swmansion.enriched.markdown.input

import com.swmansion.enriched.markdown.input.formatting.MarkdownSerializer
import com.swmansion.enriched.markdown.input.model.FormattingRange
import com.swmansion.enriched.markdown.input.model.StyleType
import org.junit.Assert.assertEquals
import org.junit.Test

class InputMarkdownSerializerTest {
  private fun range(
    type: StyleType,
    start: Int,
    end: Int,
  ) = FormattingRange(type, start, end, "https://example.com")

  @Test
  fun dropsStylesStackedInsideAWordInsteadOfWritingLiteralDelimiters() {
    val ranges =
      listOf(
        range(StyleType.BOLD, 0, 42),
        range(StyleType.ITALIC, 9, 42),
        range(StyleType.UNDERLINE, 20, 42),
        range(StyleType.STRIKETHROUGH, 29, 42),
      )

    assertEquals(
      "**bold text*italic textunderlinestrikethrough***",
      MarkdownSerializer.serialize("bold textitalic textunderlinestrikethrough", ranges),
    )
  }

  @Test
  fun keepsStackedStylesThatStartAfterASpace() {
    val ranges =
      listOf(
        range(StyleType.BOLD, 0, 39),
        range(StyleType.ITALIC, 10, 39),
        range(StyleType.UNDERLINE, 22, 39),
        range(StyleType.STRIKETHROUGH, 32, 39),
      )

    assertEquals(
      "**bold text *italic text _underline ~~strike~~_***",
      MarkdownSerializer.serialize("bold text italic text underline strike", ranges),
    )
  }

  @Test
  fun keepsBoldOverHalfAWordButDropsUnderline() {
    assertEquals("**half**word", MarkdownSerializer.serialize("halfword", listOf(range(StyleType.BOLD, 0, 4))))
    assertEquals("halfword", MarkdownSerializer.serialize("halfword", listOf(range(StyleType.UNDERLINE, 0, 4))))
  }

  @Test
  fun dropsBoldThatCannotCloseAfterPunctuationBeforeALetter() {
    assertEquals("Note:text", MarkdownSerializer.serialize("Note:text", listOf(range(StyleType.BOLD, 0, 5))))
  }

  @Test
  fun treatsAnEmojiAsPunctuation() {
    assertEquals("😀_ab_", MarkdownSerializer.serialize("😀ab", listOf(range(StyleType.UNDERLINE, 2, 4))))
  }
}
