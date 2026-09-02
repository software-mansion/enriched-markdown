package com.swmansion.enriched.markdown.compose

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.sp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.compose.test.ComposeStyleTestSupport
import org.junit.Assert.assertEquals
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
  fun resolvesSuperscriptAndSubscriptStyleOverrides() {
    var resolveContext: com.swmansion.enriched.markdown.compose.style.StyleResolveContext? = null

    composeRule.setContent {
      resolveContext = ComposeStyleTestSupport.rememberResolveContext()
    }
    composeRule.waitForIdle()

    val style =
      markdownStyle {
        superscript {
          fontScale = 0.5f
          baselineOffsetScale = 0.3f
        }
        subscript {
          fontScale = 0.6f
          baselineOffsetScale = 0.1f
        }
      }

    val resolved = style.resolve(requireNotNull(resolveContext))

    assertEquals(0.5f, resolved.superscriptStyle.fontScale, 0.001f)
    assertEquals(0.3f, resolved.superscriptStyle.baselineOffsetScale, 0.001f)
    assertEquals(0.6f, resolved.subscriptStyle.fontScale, 0.001f)
    assertEquals(0.1f, resolved.subscriptStyle.baselineOffsetScale, 0.001f)
  }
}
