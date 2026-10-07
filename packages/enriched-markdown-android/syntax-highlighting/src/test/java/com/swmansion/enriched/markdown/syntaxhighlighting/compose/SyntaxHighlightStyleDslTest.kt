@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.syntaxhighlighting.compose

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Density
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.compose.MarkdownStyle
import com.swmansion.enriched.markdown.compose.markdownStyle
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.syntaxhighlighting.SyntaxHighlightStyle
import com.swmansion.enriched.markdown.syntaxhighlighting.SyntaxHighlightStyleKey
import com.swmansion.enriched.markdown.syntaxhighlighting.SyntaxTokenType
import com.swmansion.enriched.markdown.syntaxhighlighting.syntaxHighlightStyle
import com.swmansion.enriched.markdown.syntaxhighlighting.test.SyntaxHighlightingTestSupport.context
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/** The Compose DSL, from a `syntaxHighlighting { }` block to the [StyleConfig] the view renders with. */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class SyntaxHighlightStyleDslTest {
  @Test
  fun tokenColorsResolveToArgbAndTheRestStayUnset() {
    val style =
      markdownStyle {
        syntaxHighlighting {
          keyword = Color(0xFFD73A49)
          operator = Color(0xFF112233)
        }
      }

    val stored = requireNotNull(resolveConfig(style)[SyntaxHighlightStyleKey])

    assertEquals(0xFFD73A49.toInt(), stored[SyntaxTokenType.KEYWORD])
    assertEquals(0xFF112233.toInt(), stored[SyntaxTokenType.OPERATOR])
    assertNull(stored[SyntaxTokenType.STRING])
  }

  @Test
  fun everyTokenTypeHasAProperty() {
    val colors = SyntaxTokenType.entries.associateWith { Color(0xFF000000 + it.ordinal) }

    val style =
      markdownStyle {
        syntaxHighlighting {
          keyword = colors.getValue(SyntaxTokenType.KEYWORD)
          operator = colors.getValue(SyntaxTokenType.OPERATOR)
          punctuation = colors.getValue(SyntaxTokenType.PUNCTUATION)
          string = colors.getValue(SyntaxTokenType.STRING)
          number = colors.getValue(SyntaxTokenType.NUMBER)
          constant = colors.getValue(SyntaxTokenType.CONSTANT)
          comment = colors.getValue(SyntaxTokenType.COMMENT)
          function = colors.getValue(SyntaxTokenType.FUNCTION)
          type = colors.getValue(SyntaxTokenType.TYPE)
          variable = colors.getValue(SyntaxTokenType.VARIABLE)
          property = colors.getValue(SyntaxTokenType.PROPERTY)
          tag = colors.getValue(SyntaxTokenType.TAG)
          attribute = colors.getValue(SyntaxTokenType.ATTRIBUTE)
          embedded = colors.getValue(SyntaxTokenType.EMBEDDED)
        }
      }

    val stored = requireNotNull(resolveConfig(style)[SyntaxHighlightStyleKey])

    for (type in SyntaxTokenType.entries) {
      assertEquals("$type", (0xFF000000 + type.ordinal).toInt(), stored[type])
    }
  }

  @Test
  fun aLaterBlockMergesIntoTheEarlierOne() {
    val style =
      markdownStyle {
        syntaxHighlighting {
          keyword = Color(0xFFD73A49)
          string = Color(0xFF032F62)
        }
        syntaxHighlighting {
          string = null
          comment = Color(0xFF6A737D)
          this[SyntaxTokenType.TAG] = Color(0xFF22863A)
        }
      }

    val stored = requireNotNull(resolveConfig(style)[SyntaxHighlightStyleKey])

    assertEquals(0xFFD73A49.toInt(), stored[SyntaxTokenType.KEYWORD])
    assertNull(stored[SyntaxTokenType.STRING])
    assertEquals(0xFF6A737D.toInt(), stored[SyntaxTokenType.COMMENT])
    assertEquals(0xFF22863A.toInt(), stored[SyntaxTokenType.TAG])
  }

  /** The palette under DSL colors follows the code block background the same style resolves. */
  @Test
  fun aLightCodeBlockGetsTheLightPaletteUnderTheDslColors() {
    val style =
      markdownStyle {
        codeBlock { backgroundColor = Color(0xFFF6F8FA) }
        syntaxHighlighting { keyword = Color(0xFF7C3AED) }
      }

    val resolved = resolveConfig(style).syntaxHighlightStyle()

    assertEquals(0xFF7C3AED.toInt(), resolved[SyntaxTokenType.KEYWORD])
    assertEquals(SyntaxHighlightStyle.githubLight()[SyntaxTokenType.STRING], resolved[SyntaxTokenType.STRING])
  }

  @Test
  fun anEmptyStyleReadsAsTheDarkPaletteOnCoresDefaultBlock() {
    val resolved = resolveConfig(MarkdownStyle.Default)

    assertNull(resolved[SyntaxHighlightStyleKey])
    assertEquals(SyntaxHighlightStyle.githubDark(), resolved.syntaxHighlightStyle())
  }

  private fun resolveConfig(style: MarkdownStyle): StyleConfig = style.resolveStyleConfig(context, Density(density = 2f, fontScale = 1f))
}
