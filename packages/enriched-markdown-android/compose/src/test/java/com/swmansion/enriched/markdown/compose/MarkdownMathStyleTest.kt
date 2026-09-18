package com.swmansion.enriched.markdown.compose

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.compose.test.ComposeStyleTestSupport
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.TextAlignment
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class MarkdownMathStyleTest {
  @get:Rule
  val composeRule = createComposeRule()

  private fun resolveContext(): StyleResolveContext {
    var resolveContext: StyleResolveContext? = null
    composeRule.setContent {
      resolveContext = ComposeStyleTestSupport.rememberResolveContext()
    }
    composeRule.waitForIdle()
    return requireNotNull(resolveContext)
  }

  @Test
  fun resolvesMathStyleOverridesAndKeepsUnsetDefaults() {
    val style =
      markdownStyle {
        math {
          fontSize = 24.sp
          backgroundColor = Color(0xFFEEEEEE)
          padding = 8.dp
          textAlign = TextAlignment.LEFT
        }
      }

    val resolved = style.resolve(resolveContext()).mathStyle
    val defaults = StyleConfig.default(ComposeStyleTestSupport.context).mathStyle
    val density = ComposeStyleTestSupport.testDensity

    assertEquals(with(density) { 24.sp.toPx() }, resolved.fontSize, 0.01f)
    assertEquals(0xFFEEEEEE.toInt(), resolved.backgroundColor)
    assertEquals(with(density) { 8.dp.toPx() }, resolved.padding, 0.01f)
    assertEquals(TextAlignment.LEFT, resolved.textAlign)
    assertEquals(defaults.color, resolved.color)
    assertEquals(defaults.marginBottom, resolved.marginBottom, 0.01f)
  }

  @Test
  fun resolvesInlineMathColor() {
    val style = markdownStyle { inlineMath { color = Color(0xFF7C3AED) } }

    val resolved = style.resolve(resolveContext())

    assertEquals(0xFF7C3AED.toInt(), resolved.inlineMathStyle.color)
  }

  @Test
  fun laterMathBlockMergesIntoEarlierOne() {
    val style =
      markdownStyle {
        math { fontSize = 24.sp }
        math { color = Color(0xFF112233) }
      }

    val resolved = style.resolve(resolveContext()).mathStyle

    assertEquals(with(ComposeStyleTestSupport.testDensity) { 24.sp.toPx() }, resolved.fontSize, 0.01f)
    assertEquals(0xFF112233.toInt(), resolved.color)
  }
}
