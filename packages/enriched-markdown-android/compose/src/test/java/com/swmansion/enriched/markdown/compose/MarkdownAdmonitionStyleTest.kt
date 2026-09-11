package com.swmansion.enriched.markdown.compose

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.compose.test.ComposeStyleTestSupport
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class MarkdownAdmonitionStyleTest {
  @get:Rule
  val composeRule = createComposeRule()

  private fun resolveContext(): StyleResolveContext {
    var resolveContext: StyleResolveContext? = null
    composeRule.setContent { resolveContext = ComposeStyleTestSupport.rememberResolveContext() }
    composeRule.waitForIdle()
    return requireNotNull(resolveContext)
  }

  @Test
  fun resolvesPerTypeAdmonitionOverrides() {
    val context = resolveContext()

    val resolved =
      markdownStyle {
        blockquote {
          admonitions {
            warning {
              color = Color(0xFF112233)
              backgroundColor = Color(0xFF445566)
            }
          }
        }
      }.resolve(context)

    val warning = resolved.blockquoteStyle.admonitions.getValue("warning")
    assertEquals(0xFF112233.toInt(), warning.color)
    assertEquals(0xFF445566.toInt(), warning.backgroundColor)
  }

  @Test
  fun leavesUntouchedTypesOnTheGitHubPalette() {
    val context = resolveContext()
    val defaults =
      MarkdownStyle.Default
        .resolve(context)
        .blockquoteStyle.admonitions

    val resolved =
      markdownStyle {
        blockquote { admonitions { note { color = Color.Red } } }
      }.resolve(context)

    val palette = resolved.blockquoteStyle.admonitions
    assertEquals(defaults.keys, palette.keys)
    assertEquals(0xFFFF0000.toInt(), palette.getValue("note").color)
    assertEquals(defaults.getValue("tip").color, palette.getValue("tip").color)
    assertEquals(defaults.getValue("caution").color, palette.getValue("caution").color)
  }

  @Test
  fun keepsTheColorWhenOnlyTheBackgroundIsOverridden() {
    val context = resolveContext()
    val defaults =
      MarkdownStyle.Default
        .resolve(context)
        .blockquoteStyle.admonitions

    val resolved =
      markdownStyle {
        blockquote { admonitions { tip { backgroundColor = Color(0xFFEEFFEE) } } }
      }.resolve(context)

    val tip = resolved.blockquoteStyle.admonitions.getValue("tip")
    assertEquals(defaults.getValue("tip").color, tip.color)
    assertEquals(0xFFEEFFEE.toInt(), tip.backgroundColor)
  }

  @Test
  fun layersAdmonitionOverridesAcrossCopies() {
    val context = resolveContext()

    val base = markdownStyle { blockquote { admonitions { caution { color = Color(0xFF010203) } } } }
    val derived = base.copy { blockquote { admonitions { caution { backgroundColor = Color(0xFF040506) } } } }

    val caution =
      derived
        .resolve(context)
        .blockquoteStyle.admonitions
        .getValue("caution")
    // The later layer only sets the background, so the earlier layer's color survives.
    assertEquals(0xFF010203.toInt(), caution.color)
    assertEquals(0xFF040506.toInt(), caution.backgroundColor)
  }

  @Test
  fun leavesBackgroundsUnsetByDefault() {
    val context = resolveContext()

    val palette =
      MarkdownStyle.Default
        .resolve(context)
        .blockquoteStyle.admonitions

    palette.forEach { (type, colors) -> assertNull("$type should be unfilled", colors.backgroundColor) }
  }

  @Test
  fun doesNotTouchThePaletteWhenNoAdmonitionsBlockIsUsed() {
    val context = resolveContext()
    val defaults =
      MarkdownStyle.Default
        .resolve(context)
        .blockquoteStyle.admonitions

    val resolved = markdownStyle { blockquote { borderColor = Color.Blue } }.resolve(context)

    assertEquals(defaults, resolved.blockquoteStyle.admonitions)
  }
}
