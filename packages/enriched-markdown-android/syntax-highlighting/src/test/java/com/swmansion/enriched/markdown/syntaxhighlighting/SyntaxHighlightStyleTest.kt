package com.swmansion.enriched.markdown.syntaxhighlighting

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.syntaxhighlighting.test.SyntaxHighlightingTestSupport.defaultStyle
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class SyntaxHighlightStyleTest {
  @Test
  fun thePalettesMatchIos() {
    val light = SyntaxHighlightStyle.githubLight()
    val dark = SyntaxHighlightStyle.githubDark()

    assertEquals(0xFFCF222E.toInt(), light[SyntaxTokenType.KEYWORD])
    assertEquals(0xFF0A3069.toInt(), light[SyntaxTokenType.STRING])
    assertEquals(0xFF116329.toInt(), light[SyntaxTokenType.TAG])
    assertEquals(0xFFFF7B72.toInt(), dark[SyntaxTokenType.KEYWORD])
    assertEquals(0xFFA5D6FF.toInt(), dark[SyntaxTokenType.STRING])
    assertEquals(0xFF7EE787.toInt(), dark[SyntaxTokenType.TAG])
    for (uncolored in listOf(SyntaxTokenType.OPERATOR, SyntaxTokenType.PUNCTUATION, SyntaxTokenType.VARIABLE, SyntaxTokenType.EMBEDDED)) {
      assertNull("$uncolored", light[uncolored])
      assertNull("$uncolored", dark[uncolored])
    }
  }

  @Test
  fun theDefaultPaletteFollowsTheBackgroundsLuminance() {
    assertSame(SyntaxHighlightStyle.githubDark(), SyntaxHighlightStyle.defaultFor(0xFF1F2937.toInt()))
    assertSame(SyntaxHighlightStyle.githubDark(), SyntaxHighlightStyle.defaultFor(0xFF000000.toInt()))
    assertSame(SyntaxHighlightStyle.githubLight(), SyntaxHighlightStyle.defaultFor(0xFFF6F8FA.toInt()))
    assertSame(SyntaxHighlightStyle.githubLight(), SyntaxHighlightStyle.defaultFor(0xFFFFFFFF.toInt()))
    // Nothing to judge through a transparent background.
    assertSame(SyntaxHighlightStyle.githubLight(), SyntaxHighlightStyle.defaultFor(0x00000000))
  }

  /** Core's default code block is dark. */
  @Test
  fun withNoExplicitStyleTheDefaultBlockGetsTheDarkPalette() {
    assertEquals(SyntaxHighlightStyle.githubDark(), defaultStyle.syntaxHighlightStyle())
  }

  @Test
  fun explicitColorsWinAndUnsetOnesFallBackToThePalette() {
    val explicit =
      SyntaxHighlightStyle()
        .with(SyntaxTokenType.KEYWORD, RED)
        .with(SyntaxTokenType.OPERATOR, RED)

    val resolved = defaultStyle.withExtension(SyntaxHighlightStyleKey, explicit).syntaxHighlightStyle()

    assertEquals(RED, resolved[SyntaxTokenType.KEYWORD])
    assertEquals(RED, resolved[SyntaxTokenType.OPERATOR])
    assertEquals(SyntaxHighlightStyle.githubDark()[SyntaxTokenType.STRING], resolved[SyntaxTokenType.STRING])
    // Unset in both: the block's own color.
    assertNull(resolved[SyntaxTokenType.PUNCTUATION])
  }

  @Test
  fun withCopiesAndNullUnsets() {
    val base = SyntaxHighlightStyle.githubLight()

    val changed = base.with(SyntaxTokenType.KEYWORD, RED)

    assertEquals(0xFFCF222E.toInt(), base[SyntaxTokenType.KEYWORD])
    assertEquals(RED, changed[SyntaxTokenType.KEYWORD])
    assertNull(changed.with(SyntaxTokenType.KEYWORD, null)[SyntaxTokenType.KEYWORD])
    assertNotEquals(base, changed)
    assertEquals(base, changed.with(SyntaxTokenType.KEYWORD, 0xFFCF222E.toInt()))
    assertEquals(base.hashCode(), changed.with(SyntaxTokenType.KEYWORD, 0xFFCF222E.toInt()).hashCode())
  }

  private companion object {
    const val RED = 0xFFFF0000.toInt()
  }
}
