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

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class WholeWordUnderlineTest {
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

  private fun underline(
    start: Int,
    end: Int = start,
  ): String {
    view.setSelection(start, end)
    view.toggleInlineStyle(StyleType.UNDERLINE)
    return markdown()
  }

  // The underline state the toolbar gets for the current caret or selection.
  private fun isUnderlineActive(): Boolean = view.eventEmitter.isStyleEffectivelyActive(StyleType.UNDERLINE)

  @Test
  fun caretInsideAWordUnderlinesTheWord() {
    type("an underline here")

    assertEquals("an _underline_ here", underline(6))
    assertEquals(6, view.selectionStart)
    assertEquals(6, view.selectionEnd)
  }

  @Test
  fun typingAfterwardStaysInTheUnderlinedWord() {
    type("underline")
    underline(5)
    type("X")

    assertEquals("_underXline_", markdown())
  }

  @Test
  fun selectionInsideAWordUnderlinesTheWord() {
    type("an underline here")

    assertEquals("an _underline_ here", underline(5, 8))
  }

  @Test
  fun selectionAcrossWordsGrowsBothEdges() {
    type("foo bar baz")

    assertEquals("_foo bar_ baz", underline(1, 6))
  }

  @Test
  fun selectionOfWholeWordsIsUnchanged() {
    type("foo bar baz")

    assertEquals("foo _bar_ baz", underline(4, 7))
  }

  @Test
  fun selectionStartingAtASpaceDoesNotGrow() {
    type("foo bar")

    assertEquals("foo _bar_", underline(3, 7))
  }

  @Test
  fun selectionStartingAtANoBreakSpaceDoesNotGrow() {
    type("10\u00A0km")

    assertEquals("10\u00A0_km_", underline(2, 5))
  }

  @Test
  fun selectionEndingAtANoBreakSpaceDoesNotGrow() {
    type("10\u00A0km")

    assertEquals("_10_\u00A0km", underline(0, 3))
  }

  @Test
  fun punctuationEndsTheWord() {
    type("foo(bar)")

    assertEquals("foo(_bar_)", underline(4, 7))
  }

  @Test
  fun caretAtAWordsEndTakesTheWordAndKeepsTyping() {
    type("text")
    underline(4)
    assertTrue(isUnderlineActive())
    type("underline")

    assertEquals("_textunderline_", markdown())
    assertTrue(isUnderlineActive())
  }

  @Test
  fun caretAtAWordsStartTakesTheWordAndKeepsTyping() {
    type("text")
    underline(0)
    type("pre")

    assertEquals("_pretext_", markdown())
  }

  @Test
  fun stackedStylesFromTheIssueReadBack() {
    view.toggleInlineStyle(StyleType.BOLD)
    type("bold text")
    view.toggleInlineStyle(StyleType.ITALIC)
    type("italic text")
    view.toggleInlineStyle(StyleType.UNDERLINE)
    type("underline")

    assertEquals("**bold text*italic _textunderline_***", markdown())
  }

  @Test
  fun lettersTypedAtTheStartOfAnUnderlinedWordJoinIt() {
    type("bergef")
    underline(3)
    view.setSelection(0)
    type("mn")

    assertEquals("_mnbergef_", markdown())
  }

  @Test
  fun lettersTypedRightAfterAnUnderlinedWordJoinIt() {
    type("foo bar")
    underline(4, 7)
    view.setSelection(7)
    type("s")

    assertEquals("foo _bars_", markdown())
  }

  @Test
  fun deletingTheSpaceGluesTheNextWordOn() {
    type("foo bar")
    underline(0, 3)
    view.text!!.delete(3, 4)

    assertEquals("_foobar_", markdown())
  }

  @Test
  fun caretTurnsUnderlineOffForTheWholeWord() {
    type("an underline here")
    underline(6)

    assertEquals("an underline here", underline(6))
  }

  @Test
  fun selectionTurnsUnderlineOffForTheWholeWord() {
    type("an underline here")
    underline(3, 12)

    assertEquals("an underline here", underline(5, 8))
  }

  @Test
  fun lettersTypedAfterTurningItOffAtTheWordEndStayPlain() {
    type("text")
    underline(4)
    underline(4)
    type("s more")

    assertEquals("texts more", markdown())
  }

  @Test
  fun caretAfterASpaceStillPends() {
    type("foo ")
    underline(4)
    type("bar")

    assertEquals("foo _bar_", markdown())
  }

  @Test
  fun otherStylesAreLeftAlone() {
    type("bold")
    view.setSelection(0, 4)
    view.toggleInlineStyle(StyleType.BOLD)
    view.setSelection(1, 3)
    view.toggleInlineStyle(StyleType.ITALIC)

    assertEquals("**b*ol*d**", markdown())
  }

  @Test
  fun caretAtTheEndOfAnUnderlinedWordShowsUnderline() {
    type("hello")
    underline(3)
    view.setSelection(5)

    assertTrue(isUnderlineActive())
    type("xy")
    assertEquals("_helloxy_", markdown())
    assertTrue(isUnderlineActive())
  }

  @Test
  fun oneTapAtTheEndOfAnUnderlinedWordTurnsItOff() {
    type("hello")
    underline(3)
    view.setSelection(5)
    type("xy")

    assertEquals("helloxy", underline(7))
    assertFalse(isUnderlineActive())
    type("z")
    assertEquals("helloxyz", markdown())
    assertFalse(isUnderlineActive())
  }

  @Test
  fun oneTapAtTheStartOfAnUnderlinedWordTurnsItOff() {
    type("hello")
    underline(3)
    view.setSelection(0)

    assertTrue(isUnderlineActive())
    assertEquals("hello", underline(0))
    assertFalse(isUnderlineActive())
    type("a")
    assertEquals("ahello", markdown())
  }

  @Test
  fun caretPastASpaceOrPunctuationAfterAnUnderlinedWordShowsNoUnderline() {
    type("foo! bar")
    underline(0, 3)
    view.setSelection(4)
    assertFalse(isUnderlineActive())
    view.setSelection(5)
    assertFalse(isUnderlineActive())
    type("x")

    assertEquals("_foo_! xbar", markdown())
  }
}
