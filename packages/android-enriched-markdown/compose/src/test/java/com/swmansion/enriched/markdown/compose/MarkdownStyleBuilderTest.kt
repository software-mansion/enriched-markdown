package com.swmansion.enriched.markdown.compose

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.sp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.compose.test.ComposeStyleTestSupport
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class MarkdownStyleBuilderTest {
  @get:Rule
  val composeRule = createComposeRule()

  @Test
  fun resolvesParagraphStyleOverrides() {
    var resolveContext: com.swmansion.enriched.markdown.compose.style.StyleResolveContext? = null

    composeRule.setContent {
      resolveContext = ComposeStyleTestSupport.rememberResolveContext()
    }
    composeRule.waitForIdle()

    val style =
      markdownStyle {
        paragraph {
          fontSize = 16.sp
          color = Color(0xFF112233)
        }
      }

    val resolved = style.resolve(requireNotNull(resolveContext))
    val paragraph = resolved.paragraphStyle

    assertEquals(with(ComposeStyleTestSupport.testDensity) { 16.sp.toPx() }, paragraph.fontSize, 0.01f)
    assertEquals(0xFF112233.toInt(), paragraph.color)
  }

  @Test
  fun resolvesStrikethroughAndUnderlineColors() {
    var resolveContext: com.swmansion.enriched.markdown.compose.style.StyleResolveContext? = null

    composeRule.setContent {
      resolveContext = ComposeStyleTestSupport.rememberResolveContext()
    }
    composeRule.waitForIdle()

    val style =
      markdownStyle {
        strikethrough { color = Color(0xFFFF0000) }
        underline { color = Color(0xFF0000FF) }
      }

    val resolved = style.resolve(requireNotNull(resolveContext))

    assertEquals(0xFFFF0000.toInt(), resolved.strikethroughStyle.color)
    assertEquals(0xFF0000FF.toInt(), resolved.underlineStyle.color)
  }

  @Test
  fun leavesStrikethroughAndUnderlineColorsUnsetByDefault() {
    var resolveContext: com.swmansion.enriched.markdown.compose.style.StyleResolveContext? = null

    composeRule.setContent {
      resolveContext = ComposeStyleTestSupport.rememberResolveContext()
    }
    composeRule.waitForIdle()

    val resolved = markdownStyle { paragraph { fontSize = 16.sp } }.resolve(requireNotNull(resolveContext))

    assertNull(resolved.strikethroughStyle.color)
    assertNull(resolved.underlineStyle.color)
  }
}
