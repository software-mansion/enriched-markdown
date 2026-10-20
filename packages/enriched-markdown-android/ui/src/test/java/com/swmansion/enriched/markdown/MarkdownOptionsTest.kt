package com.swmansion.enriched.markdown

import com.swmansion.enriched.markdown.parser.Md4cFlags
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import java.lang.reflect.Modifier

class MarkdownOptionsTest {
  @Test
  fun everyFlagReachesTheParserAsSet() {
    val options =
      MarkdownOptions(
        underline = true,
        superscript = true,
        subscript = true,
        highlight = true,
        permissiveAutolinks = false,
        hardSoftBreaks = true,
        preserveBlankLines = true,
        admonitions = true,
      )

    assertEquals(
      Md4cFlags(
        underline = true,
        superscript = true,
        subscript = true,
        highlight = true,
        permissiveAutolinks = false,
        hardSoftBreaks = true,
        preserveBlankLines = true,
        admonitions = true,
      ),
      options.toParserFlags(),
    )
  }

  @Test
  fun theDefaultsMatchTheParsersWithMathOff() {
    assertEquals(Md4cFlags.Default.copy(latexMath = false), MarkdownOptions.Default.toParserFlags())
    assertFalse(MarkdownOptions.Default.toParserFlags().latexMath)
  }

  /** A parser flag added without a [MarkdownOptions] counterpart would silently stay at its default. */
  @Test
  fun flagsCoversEveryParserFlagButMath() {
    assertEquals(fieldNames(Md4cFlags::class.java) - "latexMath", fieldNames(MarkdownOptions::class.java))
  }

  private fun fieldNames(type: Class<*>): Set<String> =
    type.declaredFields
      .filterNot { Modifier.isStatic(it.modifiers) }
      .mapTo(HashSet()) { it.name }
}
