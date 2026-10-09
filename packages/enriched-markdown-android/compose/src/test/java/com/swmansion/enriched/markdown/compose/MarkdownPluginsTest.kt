@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.compose

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PluginRegistry
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class MarkdownPluginsTest {
  @get:Rule
  val composeRule = createComposeRule()

  @Test
  fun outsideEveryScopeNoPluginsAreProvided() {
    var captured: List<MarkdownPlugin>? = null

    composeRule.setContent {
      captured = LocalMarkdownPlugins.current
    }

    assertEquals(emptyList<MarkdownPlugin>(), captured)
  }

  @Test
  fun nestedScopesAddUpAcrossAMarkdownTheme() {
    var captured: List<MarkdownPlugin>? = null

    composeRule.setContent {
      pluginA {
        MarkdownTheme(style = MarkdownStyle.Default) {
          pluginB {
            captured = LocalMarkdownPlugins.current
          }
        }
      }
    }

    assertEquals(listOf(pluginA, pluginB), captured)
  }

  @Test
  fun anInnerScopeForTheSameIdReplacesTheOuterPlugin() {
    val reconfiguredA = NoOpPlugin("a")
    var captured: List<MarkdownPlugin>? = null

    composeRule.setContent {
      pluginA {
        pluginB {
          reconfiguredA {
            captured = LocalMarkdownPlugins.current
          }
        }
      }
    }

    assertEquals(listOf(pluginB, reconfiguredA), captured)
  }

  private class NoOpPlugin(
    override val id: String,
  ) : MarkdownPlugin {
    override fun install(registry: PluginRegistry) = Unit
  }

  private val pluginA: MarkdownPlugin = NoOpPlugin("a")
  private val pluginB: MarkdownPlugin = NoOpPlugin("b")
}
