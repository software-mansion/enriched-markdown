package com.swmansion.enriched.markdown.parser

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class LatexSpeechTest {
  @Test
  fun formulaIsSpokenInEnglish() {
    assertEquals("fraction e to the power x over 2 end fraction", LatexSpeech.spokenForm("\\frac{e^x}{2}"))
    assertEquals("x squared", LatexSpeech.spokenForm("x^2"))
  }

  @Test
  fun textOutsideAsciiSurvivesTheRoundTrip() {
    assertEquals("über alpha", LatexSpeech.spokenForm("\\text{über} \\alpha"))
  }

  @Test
  fun emptySourceIsEmpty() {
    assertEquals("", LatexSpeech.spokenForm(""))
  }
}
