package com.swmansion.enriched.markdown.math

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.compose.LocalMarkdownPlugins
import com.swmansion.enriched.markdown.plugin.MarkdownPlugin
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class LatexMathPluginScopeTest {
  @get:Rule
  val composeRule = createComposeRule()

  // Deliberately without importing `com.swmansion.enriched.markdown.compose.MarkdownPlugins`: the
  // scope must resolve through the plugin's own name alone.
  @Test
  fun theScopeEnablesThePluginThroughItsOwnName() {
    var captured: List<MarkdownPlugin>? = null

    composeRule.setContent {
      LatexMathPlugin {
        captured = LocalMarkdownPlugins.current
      }
    }

    assertEquals(listOf(LatexMathPlugin), captured)
  }
}
