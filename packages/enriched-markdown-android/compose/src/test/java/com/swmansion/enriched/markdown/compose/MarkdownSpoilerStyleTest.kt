package com.swmansion.enriched.markdown.compose

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.dp
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
  fun resolvesTheParticleAndSolidSubScopes() {
    val context = resolveContext()

    val resolved =
      markdownStyle {
        spoiler {
          particles {
            density = 16f
            speed = 40f
          }
          solid { cornerRadius = 6.dp }
        }
      }.resolve(context)

    assertEquals(16f, resolved.spoilerStyle.particleDensity, 0.001f)
    assertEquals(40f, resolved.spoilerStyle.particleSpeed, 0.001f)
    // The test density is 2, and the resolved radius is in pixels.
    assertEquals(12f, resolved.spoilerStyle.solidCornerRadius, 0.001f)
  }

  @Test
  fun leavesUntouchedPropertiesOnTheirDefaults() {
    val context = resolveContext()
    val defaults = MarkdownStyle.Default.resolve(context).spoilerStyle

    val resolved = markdownStyle { spoiler { particles { density = 3f } } }.resolve(context)

    assertEquals(3f, resolved.spoilerStyle.particleDensity, 0.001f)
    assertEquals(defaults.color, resolved.spoilerStyle.color)
    assertEquals(defaults.particleSpeed, resolved.spoilerStyle.particleSpeed, 0.001f)
    assertEquals(defaults.solidCornerRadius, resolved.spoilerStyle.solidCornerRadius, 0.001f)
  }

  @Test
  fun layersSpoilerOverridesAcrossMerges() {
    val context = resolveContext()

    val base = markdownStyle { spoiler { color = Color(0xFF010203) } }
    val derived = base.merge { spoiler { solid { cornerRadius = 2.dp } } }

    val resolved = derived.resolve(context).spoilerStyle
    // The later layer only sets the radius, so the earlier layer's color survives.
    assertEquals(0xFF010203.toInt(), resolved.color)
    assertEquals(4f, resolved.solidCornerRadius, 0.001f)
  }

  @Test
  fun aSecondParticlesBlockInTheSameScopeMergesRatherThanReplaces() {
    val context = resolveContext()

    val resolved =
      markdownStyle {
        spoiler {
          particles { density = 5f }
          particles { speed = 7f }
        }
      }.resolve(context)

    assertEquals(5f, resolved.spoilerStyle.particleDensity, 0.001f)
    assertEquals(7f, resolved.spoilerStyle.particleSpeed, 0.001f)
  }

  @Test
  fun doesNotTouchTheSpoilerStyleWhenNoSpoilerBlockIsUsed() {
    val context = resolveContext()
    val defaults = MarkdownStyle.Default.resolve(context).spoilerStyle

    val resolved = markdownStyle { paragraph { color = Color.Blue } }.resolve(context)

    assertEquals(defaults, resolved.spoilerStyle)
  }
}
