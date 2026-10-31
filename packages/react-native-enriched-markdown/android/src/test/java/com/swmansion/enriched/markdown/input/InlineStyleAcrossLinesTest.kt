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
class InlineStyleAcrossLinesTest {
  private var view = EnrichedMarkdownTextInputView(RuntimeEnvironment.getApplication())

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

  private fun styleEverything(style: StyleType = StyleType.BOLD): String {
    view.setSelection(0, view.text!!.length)
    view.toggleInlineStyle(style)
    return markdown()
  }

  @Test
  fun closesBoldInEachBulletItem() {
    view.toggleUnorderedList()
    type("One\nTwo")

    assertEquals("- **One**\n- **Two**", styleEverything())
  }

  @Test
  fun closesBoldInEachOrderedItem() {
    view.toggleOrderedList()
    type("One\nTwo")

    assertEquals("1. **One**\n2. **Two**", styleEverything())
  }

  @Test
  fun closesBoldInTheHeading() {
    view.toggleHeading(1)
    type("Title\nBody")

    assertEquals("# **Title**\n**Body**", styleEverything())
  }

  @Test
  fun closesBoldInEachParagraph() {
    type("One\n\nTwo")

    assertEquals("**One**\n\n**Two**", styleEverything())
  }

  @Test
  fun closesEveryInlineStyleInEachBulletItem() {
    val delimiters =
      mapOf(
        StyleType.ITALIC to ("*" to "*"),
        StyleType.UNDERLINE to ("_" to "_"),
        StyleType.STRIKETHROUGH to ("~~" to "~~"),
        StyleType.SPOILER to ("||" to "||"),
      )
    for ((style, delimiter) in delimiters) {
      view = EnrichedMarkdownTextInputView(RuntimeEnvironment.getApplication())
      view.toggleUnorderedList()
      type("One\nTwo")

      val (open, close) = delimiter
      assertEquals("$style", "- ${open}One$close\n- ${open}Two$close", styleEverything(style))
    }
  }

  @Test
  fun closesALinkInEachBulletItem() {
    view.toggleUnorderedList()
    type("One\nTwo")
    view.setLinkForRange("https://example.com", 0, view.text!!.length)

    assertEquals("- [One](https://example.com)\n- [Two](https://example.com)", markdown())
  }

  @Test
  fun skipsAnEmptyBulletItemInsideTheRange() {
    view.toggleUnorderedList()
    type("One\nTwo")
    view.setSelection(3)
    type("\n")

    assertEquals("- **One**\n\n- **Two**", styleEverything())
  }

  @Test
  fun leavesBoldOnOneBulletItemUnchanged() {
    view.toggleUnorderedList()
    type("One\nTwo")
    view.setSelection(view.text!!.length - 3, view.text!!.length)
    view.toggleInlineStyle(StyleType.BOLD)

    assertEquals("- One\n- **Two**", markdown())
  }
}
