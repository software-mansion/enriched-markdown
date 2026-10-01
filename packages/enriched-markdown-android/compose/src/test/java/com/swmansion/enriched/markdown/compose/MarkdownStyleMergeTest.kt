package com.swmansion.enriched.markdown.compose

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.compose.test.ComposeStyleTestSupport
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class MarkdownStyleMergeTest {
  @get:Rule
  val composeRule = createComposeRule()

  private val base =
    markdownStyle {
      paragraph { color = Color(0xFF111111) }
      link { color = Color(0xFF0066CC) }
    }

  @Test
  fun mergeLayerOverridesEarlierValues() {
    var resolveContext: com.swmansion.enriched.markdown.compose.style.StyleResolveContext? = null

    composeRule.setContent {
      resolveContext = ComposeStyleTestSupport.rememberResolveContext()
    }
    composeRule.waitForIdle()

    val darkStyle =
      base.merge {
        paragraph { color = Color(0xFFE0E0E0) }
        link { color = Color(0xFF6CB6FF) }
      }

    val resolved = darkStyle.resolve(requireNotNull(resolveContext))

    assertEquals(0xFFE0E0E0.toInt(), resolved.paragraphStyle.color)
    assertEquals(0xFF6CB6FF.toInt(), resolved.linkStyle.color)
  }

  @Test
  fun plusLayersTheRightHandStyleOnTop() {
    var resolveContext: com.swmansion.enriched.markdown.compose.style.StyleResolveContext? = null

    composeRule.setContent {
      resolveContext = ComposeStyleTestSupport.rememberResolveContext()
    }
    composeRule.waitForIdle()

    val overrides = markdownStyle { paragraph { color = Color(0xFFE0E0E0) } }

    val resolved = (base + overrides).resolve(requireNotNull(resolveContext))

    assertEquals(0xFFE0E0E0.toInt(), resolved.paragraphStyle.color)
    // The right-hand style says nothing about links, so the left-hand value survives.
    assertEquals(0xFF0066CC.toInt(), resolved.linkStyle.color)
  }
}
