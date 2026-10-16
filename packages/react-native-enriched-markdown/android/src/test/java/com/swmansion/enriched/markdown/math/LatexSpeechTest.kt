package com.swmansion.enriched.markdown.math

import com.swmansion.enriched.markdown.accessibility.AccessibilityLabels
import org.junit.Assert.assertEquals
import org.junit.Test

class LatexSpeechTest {
  private fun speak(latex: String): String = LatexSpeech.spokenForm(latex)

  @Test
  fun powersAndIndices() {
    assertEquals("x squared", speak("x^2"))
    assertEquals("x cubed", speak("x^3"))
    assertEquals("x to the power n", speak("x^n"))
    assertEquals("x to the power of n plus 1 end power", speak("x^{n+1}"))
    assertEquals("e to the power of i pi end power plus 1 equals 0", speak("""e^{i\pi} + 1 = 0"""))
    assertEquals("x sub 1 less than or equal to y sub max", speak("""x_1 \leq y_{max}"""))
    assertEquals("a sub i j", speak("a_{ij}"))
    assertEquals("x sub i squared", speak("x_i^2"))
  }

  @Test
  fun fractionsAndRoots() {
    assertEquals("1 over 3", speak("""\frac{1}{3}"""))
    assertEquals("1 over n squared", speak("""\frac{1}{n^2}"""))
    assertEquals("fraction a plus b over 2 end fraction", speak("""\frac{a+b}{2}"""))
    assertEquals("square root of 2", speak("""\sqrt{2}"""))
    assertEquals("square root of a squared plus b squared end root", speak("""\sqrt{a^2+b^2}"""))
    assertEquals("cube root of 8", speak("""\sqrt[3]{8}"""))
    assertEquals("root n of x", speak("""\sqrt[n]{x}"""))
    assertEquals("n choose k", speak("""\binom{n}{k}"""))
  }

  @Test
  fun bigOperatorsWithBounds() {
    assertEquals("integral from 0 to 1 of x squared d x equals 1 over 3", speak("""\int_0^1 x^2 \, dx = \frac{1}{3}"""))
    assertEquals("sum from n equals 1 to infinity of 1 over n squared", speak("""\sum_{n=1}^{\infty} \frac{1}{n^2}"""))
    assertEquals("limit as x approaches 0 of fraction sine x over x end fraction", speak("""\lim_{x \to 0} \frac{\sin x}{x}"""))
    assertEquals("product from i of a sub i", speak("""\prod_{i} a_i"""))
    assertEquals("f colon A to B", speak("""f: A \to B"""))
    assertEquals("integral of f", speak("""\int f"""))
  }

  @Test
  fun symbolsLettersAndText() {
    assertEquals("alpha squared plus capital pi", speak("""\alpha^2 + \Pi"""))
    assertEquals("epsilon greater than 0", speak("""\varepsilon > 0"""))
    assertEquals("a not equal to b", speak("""a \neq b"""))
    assertEquals("open paren a plus b close paren squared", speak("""\left( a + b \right)^2"""))
    assertEquals("f vertical bar sub 0 to the power 1", speak("""\left. f \right|_0^1"""))
    assertEquals("n factorial times f prime open paren x close paren", speak("""n! \cdot f'(x)"""))
    assertEquals("vector v times n hat", speak("""\vec{v} \cdot \hat{n}"""))
    assertEquals("speed equals 5 m over s", speak("""\text{speed} = 5 \, \mathrm{m/s}"""))
    assertEquals("x in R", speak("""x \in \mathbb{R}"""))
    assertEquals("3.14 approximately equal to pi", speak("""3.14 \approx \pi"""))
  }

  @Test
  fun unknownCommandsKeepTheirName() {
    assertEquals("foo x", speak("""\foo{x}"""))
  }

  @Test
  fun scriptsReadSubBeforePowerRegardlessOfOrder() {
    assertEquals(speak("x_i^2"), speak("x^2_i"))
  }

  @Test
  fun malformedInputDoesNotCrash() {
    assertEquals("", speak(""))
    for (latex in listOf("""\frac{1}""", "x^", "}{", "\\", "{", """\sqrt[""", "^_^")) {
      speak(latex)
    }
  }

  @Test
  fun labelTemplateResolvesBothPlaceholders() {
    assertEquals("Formel: x squared (x^2)", AccessibilityLabels(mathEquation = "Formel: {speech} ({latex})").mathLabel("x^2"))
    assertEquals("Math: x^2", AccessibilityLabels(mathEquation = "Math: {latex}").mathLabel("x^2"))
    assertEquals("Math", AccessibilityLabels(mathEquation = "Math").mathLabel("x^2"))
  }
}
