package com.swmansion.enriched.markdown.parser

import android.text.TestSpannable
import android.text.style.UnderlineSpan
import com.swmansion.enriched.markdown.EnrichedMarkdownText
import com.swmansion.enriched.markdown.spans.CodeSpan
import com.swmansion.enriched.markdown.spans.LinkSpan
import com.swmansion.enriched.markdown.spans.StrongSpan
import com.swmansion.enriched.markdown.utils.text.conversion.MarkdownExtractor

/** Runs the production MarkdownExtractor against deterministic span metadata. */
object RecognizedLinkCopyTest {
  @JvmStatic
  fun main(args: Array<String>) {
    val tests =
      listOf(
        "partial selected recognized text copies as original plain text" to ::recognizedText,
        "partial selected recognized inline code retains backticks" to ::recognizedCode,
        "clipped selections inside recognized links preserve text and code" to ::clippedSelections,
        "partial selected explicit Markdown links retain their URL" to ::explicitLink,
        "mixed recognized and explicit links preserve each copy behavior" to ::mixedLinks,
        "recognized links retain explicit surrounding formatting" to ::formatting,
        "full selection still returns the original Markdown source" to ::fullSource,
      )
    tests.forEach { (name, test) ->
      try {
        test()
        println("PASS: $name")
      } catch (failure: Throwable) {
        throw AssertionError("FAIL: $name", failure)
      }
    }
    println("${tests.size} production MarkdownExtractor copy tests passed")
  }

  private fun fixture(
    label: String,
    recognized: Boolean,
    code: Boolean = false,
  ): TestSpannable {
    val content = "prefix $label suffix"
    return TestSpannable(content).apply {
      span(LinkSpan(if (recognized) label else "https://original.invalid", recognized), 7, 7 + label.length)
      if (code) span(CodeSpan(), 7, 7 + label.length)
    }
  }

  private fun selected(
    spannable: TestSpannable,
    start: Int,
    end: Int,
  ): String? {
    val view =
      EnrichedMarkdownText().apply {
        text = spannable
        currentMarkdown = "original source is used only for a full selection"
        selectionStart = start
        selectionEnd = end
      }
    return MarkdownExtractor.getMarkdownForSelection(view)
  }

  private fun assertEquals(
    expected: Any?,
    actual: Any?,
  ) {
    check(expected == actual) { "Expected <$expected>, got <$actual>" }
  }

  private fun recognizedText() {
    assertEquals("item-12", selected(fixture("item-12", recognized = true), 7, 14))
  }

  private fun recognizedCode() {
    assertEquals("`item-34`", selected(fixture("item-34", recognized = true, code = true), 7, 14))
  }

  private fun clippedSelections() {
    assertEquals("em-12", selected(fixture("item-12", recognized = true), 9, 14))
    assertEquals("`em-34`", selected(fixture("item-34", recognized = true, code = true), 9, 14))
  }

  private fun explicitLink() {
    assertEquals("[item-56](https://original.invalid)", selected(fixture("item-56", recognized = false), 7, 14))
    assertEquals("[em-56](https://original.invalid)", selected(fixture("item-56", recognized = false), 9, 14))
  }

  private fun mixedLinks() {
    val spannable =
      TestSpannable("item-12 item-34 item-56")
        .span(LinkSpan("item-12", recognizedLink = true), 0, 7)
        .span(LinkSpan("item-34", recognizedLink = true), 8, 15)
        .span(CodeSpan(), 8, 15)
        .span(LinkSpan("https://original.invalid"), 16, 23)
    assertEquals(
      "item-12 `item-34` [item-56](https://original.invalid)",
      MarkdownExtractor.extractFromSpannable(spannable, 0, spannable.length),
    )
  }

  private fun formatting() {
    val spannable =
      fixture("item-12", recognized = true)
        .span(StrongSpan(), 7, 14)
        .span(UnderlineSpan(), 7, 14)
    assertEquals("**<u>item-12</u>**", selected(spannable, 7, 14))
  }

  private fun fullSource() {
    val source = "item-12 and `item-34`"
    val spannable =
      TestSpannable("item-12 and item-34")
        .span(LinkSpan("item-12", recognizedLink = true), 0, 7)
        .span(LinkSpan("item-34", recognizedLink = true), 12, 19)
        .span(CodeSpan(), 12, 19)
    val view =
      EnrichedMarkdownText().apply {
        text = spannable
        currentMarkdown = source
        selectionStart = 0
        selectionEnd = spannable.length
      }
    assertEquals(source, MarkdownExtractor.getMarkdownForSelection(view))
  }
}
