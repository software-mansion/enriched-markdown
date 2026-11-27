@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.math

import com.swmansion.enriched.markdown.parser.Md4cFlags
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import org.junit.Assert.assertEquals
import org.junit.Test

class LatexMathPluginFlagsTest {
  @Test
  fun enablingThePluginTurnsOnMathParsing() {
    assertEquals(
      Md4cFlags(underline = true, latexMath = true),
      LatexMathPlugin.adjustParserFlags(Md4cFlags(underline = true)),
    )
  }
}
