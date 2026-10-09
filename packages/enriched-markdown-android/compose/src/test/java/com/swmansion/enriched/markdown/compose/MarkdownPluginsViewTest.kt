@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.compose

import android.view.View
import android.view.ViewGroup
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.EnrichedMarkdown
import com.swmansion.enriched.markdown.plugin.CodeBlockDecorator
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PluginRegistry
import com.swmansion.enriched.markdown.plugin.PluginSnapshot
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * What the plugin scopes hand [EnrichedMarkdownText]'s view. The markdown is left empty: rendering
 * it needs the native parser, and the snapshot is all the view's render path takes from the scopes.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class MarkdownPluginsViewTest {
  @get:Rule
  val composeRule = createComposeRule()

  @Test
  fun scopedCodeBlockDecoratorsReachTheViewInScopeOrder() {
    val outer = CodeBlockDecorator { _, _, _, _, _, _ -> }
    val inner = CodeBlockDecorator { _, _, _, _, _, _ -> }
    val outerPlugin = DecoratingPlugin("outer", outer)
    val innerPlugin = DecoratingPlugin("inner", inner)
    lateinit var root: View

    composeRule.setContent {
      root = LocalView.current
      MarkdownPlugins(outerPlugin) {
        MarkdownPlugins(innerPlugin) {
          EnrichedMarkdownText(markdown = "")
        }
      }
    }
    composeRule.waitForIdle()

    val view = root.findDescendant<EnrichedMarkdown>()
    assertEquals(listOf(outer, inner), view.pluginSnapshot().codeBlockDecorators)
  }

  private class DecoratingPlugin(
    override val id: String,
    private val decorator: CodeBlockDecorator,
  ) : MarkdownPlugin {
    override fun install(registry: PluginRegistry) = registry.registerCodeBlockDecorator(decorator)
  }

  private inline fun <reified T : View> View.findDescendant(): T =
    checkNotNull(descendants().filterIsInstance<T>().firstOrNull()) { "No ${T::class.java.simpleName} under $this" }

  private fun View.descendants(): Sequence<View> =
    sequence {
      yield(this@descendants)
      if (this@descendants is ViewGroup) {
        for (i in 0 until childCount) yieldAll(getChildAt(i).descendants())
      }
    }

  private fun EnrichedMarkdown.pluginSnapshot(): PluginSnapshot {
    val field = EnrichedMarkdown::class.java.getDeclaredField("pluginSnapshot")
    field.isAccessible = true
    return field.get(this) as PluginSnapshot
  }
}
