package com.swmansion.enriched.markdown.codehighlight

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.codehighlight.test.CodeHighlightTestSupport.defaultStyle
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class CodeHighlightStyleTest {
  @Test
  fun withNoExplicitStyleTheDefaultPaletteApplies() {
    assertEquals(CodeHighlightStyle.Default, defaultStyle.codeHighlightStyle())
  }

  @Test
  fun explicitColorsWinAndUnsetOnesFallBackToThePalette() {
    val explicit = CodeHighlightStyle(keyword = RED, operator = RED)

    val resolved = defaultStyle.withExtension(CodeHighlightStyleKey, explicit).codeHighlightStyle()

    assertEquals(RED, resolved[SyntaxTokenType.KEYWORD])
    assertEquals(RED, resolved[SyntaxTokenType.OPERATOR])
    assertEquals(CodeHighlightStyle.Default[SyntaxTokenType.STRING], resolved[SyntaxTokenType.STRING])
    // Unset in both: the block's own color.
    assertNull(resolved[SyntaxTokenType.PUNCTUATION])
  }

  @Test
  fun getReadsTheFieldForEachTokenType() {
    val style = CodeHighlightStyle.of { it.ordinal }

    for (type in SyntaxTokenType.entries) {
      assertEquals("$type", type.ordinal, style[type])
    }
  }

  private companion object {
    const val RED = 0xFFFF0000.toInt()
  }
}
