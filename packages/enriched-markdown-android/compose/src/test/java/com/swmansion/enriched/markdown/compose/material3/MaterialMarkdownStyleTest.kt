package com.swmansion.enriched.markdown.compose.material3

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.compose.MarkdownStyle
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.compose.test.ComposeStyleTestSupport
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class MaterialMarkdownStyleTest {
  @get:Rule
  val composeRule = createComposeRule()

  private val light = lightColorScheme()
  private val dark = darkColorScheme()

  private fun resolveContext(): StyleResolveContext {
    var resolveContext: StyleResolveContext? = null
    composeRule.setContent { resolveContext = ComposeStyleTestSupport.rememberResolveContext() }
    composeRule.waitForIdle()
    return requireNotNull(resolveContext)
  }

  @Test
  fun colorsComeFromTheScheme() {
    val resolved = materialMarkdownStyle(dark).resolve(resolveContext())

    assertEquals(dark.onSurface.toArgb(), resolved.paragraphStyle.color)
    assertEquals(dark.onSurface.toArgb(), resolved.headingStyles[1]?.color)
    assertEquals(dark.primary.toArgb(), resolved.linkStyle.color)
    assertEquals(dark.surfaceContainer.toArgb(), resolved.codeBlockStyle.backgroundColor)
    assertEquals(dark.surfaceContainerHigh.toArgb(), resolved.tableStyle.headerBackgroundColor)
    assertEquals(
      dark.error.toArgb(),
      resolved.blockquoteStyle.admonitions
        .getValue("caution")
        .color,
    )
  }

  /** Admonitions have no Material tokens, so their palette follows the scheme's brightness. */
  @Test
  fun admonitionsFollowTheSchemesBrightness() {
    val context = resolveContext()

    val onLight = materialMarkdownStyle(light).resolve(context).blockquoteStyle.admonitions
    val onDark = materialMarkdownStyle(dark).resolve(context).blockquoteStyle.admonitions

    assertEquals(0xFF0969DA.toInt(), onLight.getValue("note").color)
    assertEquals(0xFF4493F8.toInt(), onDark.getValue("note").color)
  }

  @Test
  fun rememberedStyleFollowsASchemeSwitch() {
    var scheme by mutableStateOf(light)
    var style: MarkdownStyle? = null
    composeRule.setContent {
      MaterialTheme(colorScheme = scheme) { style = rememberMaterialMarkdownStyle() }
    }
    composeRule.waitForIdle()
    assertEquals(materialMarkdownStyle(light), style)

    scheme = dark
    composeRule.waitForIdle()

    assertEquals(materialMarkdownStyle(dark), style)
  }

  @Test
  fun aCustomSchemesColorsAreUsed() {
    val brand = light.copy(primary = Color(0xFF00897B))

    val resolved = materialMarkdownStyle(brand).resolve(resolveContext())

    assertEquals(0xFF00897B.toInt(), resolved.linkStyle.color)
  }
}
