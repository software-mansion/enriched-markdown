package com.swmansion.enriched.markdown.compose

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.compose.test.ComposeStyleTestSupport
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class MarkdownSpoilerStyleTest {
  @get:Rule
  val composeRule = createComposeRule()

  private fun resolveContext(): StyleResolveContext {
    var resolveContext: StyleResolveContext? = null
    composeRule.setContent { resolveContext = ComposeStyleTestSupport.rememberResolveContext() }
    composeRule.waitForIdle()
    return requireNotNull(resolveContext)
  }

  @Test
  fun resolvesTheOverlayColor() {
    val context = resolveContext()

    val resolved = markdownStyle { spoiler { color = Color(0xFF112233) } }.resolve(context)

    assertEquals(0xFF112233.toInt(), resolved.spoilerStyle.color)
  }

  @Test
  fun layersSpoilerOverridesAcrossMerges() {
    val context = resolveContext()

    val base = markdownStyle { spoiler { color = Color(0xFF010203) } }
    val derived = base.merge { paragraph { color = Color.Blue } }
    val overridden = base.merge { spoiler { color = Color(0xFF040506) } }

    // A later layer without a spoiler block keeps the earlier layer's color; one with it wins.
    assertEquals(0xFF010203.toInt(), derived.resolve(context).spoilerStyle.color)
    assertEquals(0xFF040506.toInt(), overridden.resolve(context).spoilerStyle.color)
  }

  @Test
  fun doesNotTouchTheSpoilerStyleWhenNoSpoilerBlockIsUsed() {
    val context = resolveContext()
    val defaults = MarkdownStyle.Default.resolve(context).spoilerStyle

    val resolved = markdownStyle { paragraph { color = Color.Blue } }.resolve(context)

    assertEquals(defaults, resolved.spoilerStyle)
  }
}
