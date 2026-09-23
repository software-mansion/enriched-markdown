@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.math.compose

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.compose.MarkdownStyle
import com.swmansion.enriched.markdown.compose.markdownStyle
import com.swmansion.enriched.markdown.math.InlineMathStyleKey
import com.swmansion.enriched.markdown.math.MathStyleKey
import com.swmansion.enriched.markdown.math.test.MathTestSupport.context
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.StyleExtensionKey
import com.swmansion.enriched.markdown.styles.TextAlignment
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * The Compose DSL, from a `math { }` block to the [StyleConfig] the view renders with, resolved at
 * a fixed density so the px assertions mean something.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class MathStyleDslTest {
  @Test
  fun mathOverridesResolveAndUnsetPropertiesKeepThePluginsDefaults() {
    val style =
      markdownStyle {
        math {
          fontSize = 24.sp
          backgroundColor = Color(0xFFEEEEEE)
          padding = 8.dp
          textAlign = TextAlignment.LEFT
        }
      }

    val resolved = resolve(style, MathStyleKey)

    assertEquals(24f * DENSITY, resolved.fontSize, 0.01f)
    assertEquals(0xFFEEEEEE.toInt(), resolved.backgroundColor)
    assertEquals(8f * DENSITY, resolved.padding, 0.01f)
    assertEquals(TextAlignment.LEFT, resolved.textAlign)
    // Untouched: the plugin's own defaults, which core never had to know.
    assertEquals(0xFF1F2937.toInt(), resolved.color)
    assertEquals(16f * DENSITY, resolved.marginBottom, 0.01f)
    assertEquals(0f, resolved.marginTop, 0.01f)
  }

  @Test
  fun inlineMathColorResolves() {
    val resolved = resolve(markdownStyle { inlineMath { color = Color(0xFF7C3AED) } }, InlineMathStyleKey)

    assertEquals(0xFF7C3AED.toInt(), resolved.color)
  }

  @Test
  fun aLaterMathBlockMergesIntoTheEarlierOne() {
    val style =
      markdownStyle {
        math { fontSize = 24.sp }
        math { color = Color(0xFF112233) }
      }

    val resolved = resolve(style, MathStyleKey)

    assertEquals(24f * DENSITY, resolved.fontSize, 0.01f)
    assertEquals(0xFF112233.toInt(), resolved.color)
  }

  @Test
  fun aKeyNoBlockTouchedStaysAbsent() {
    assertNull(resolveConfig(markdownStyle { math { fontSize = 24.sp } })[InlineMathStyleKey])
  }

  @Test
  fun anEmptyStyleLeavesBothKeysToThePluginsOwnDefaults() {
    val resolved = resolveConfig(MarkdownStyle.Default)

    assertNull(resolved[MathStyleKey])
    assertNull(resolved[InlineMathStyleKey])
  }

  private fun <T : Any> resolve(
    style: MarkdownStyle,
    key: StyleExtensionKey<T>,
  ): T = requireNotNull(resolveConfig(style)[key]) { "Nothing resolved under $key" }

  private fun resolveConfig(style: MarkdownStyle): StyleConfig =
    style.resolveStyleConfig(context, Density(density = DENSITY, fontScale = 1f))

  private companion object {
    const val DENSITY = 2f
  }
}
