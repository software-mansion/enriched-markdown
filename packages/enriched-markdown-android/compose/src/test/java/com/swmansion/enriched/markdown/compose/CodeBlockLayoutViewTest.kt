package com.swmansion.enriched.markdown.compose

import android.view.View
import android.view.ViewGroup
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.EnrichedMarkdown
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/** What [EnrichedMarkdownText] hands its view. The markdown is left empty: rendering it needs the native parser. */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class CodeBlockLayoutViewTest {
  @get:Rule
  val composeRule = createComposeRule()

  @Test
  fun codeBlocksWrapByDefault() {
    lateinit var root: View

    composeRule.setContent {
      root = LocalView.current
      EnrichedMarkdownText(markdown = "")
    }
    composeRule.waitForIdle()

    assertEquals(CodeBlockLayout.Wrapping, root.findDescendant<EnrichedMarkdown>().codeBlockLayout)
  }

  @Test
  fun theLayoutReachesTheViewAndFollowsRecomposition() {
    lateinit var root: View
    var layout by mutableStateOf(CodeBlockLayout.Scrollable)

    composeRule.setContent {
      root = LocalView.current
      EnrichedMarkdownText(markdown = "", codeBlockLayout = layout)
    }
    composeRule.waitForIdle()
    val view = root.findDescendant<EnrichedMarkdown>()
    assertEquals(CodeBlockLayout.Scrollable, view.codeBlockLayout)

    layout = CodeBlockLayout.Wrapping
    composeRule.waitForIdle()

    assertEquals(CodeBlockLayout.Wrapping, view.codeBlockLayout)
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
}
