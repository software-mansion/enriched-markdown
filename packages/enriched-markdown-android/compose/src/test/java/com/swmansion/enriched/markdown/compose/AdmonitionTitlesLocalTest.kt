package com.swmansion.enriched.markdown.compose

import android.view.View
import android.view.ViewGroup
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.EnrichedMarkdown
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class AdmonitionTitlesLocalTest {
  @get:Rule
  val composeRule = createComposeRule()

  private val provided = AdmonitionTitles(note = "Uwaga")

  @Test
  fun aViewWithoutItsOwnTitlesTakesTheLocalOnes() {
    val titles =
      viewTitles {
        CompositionLocalProvider(LocalAdmonitionTitles provides provided) {
          EnrichedMarkdownText(markdown = "")
        }
      }

    assertEquals(provided, titles)
  }

  @Test
  fun titlesPassedToTheViewWinOverTheLocalOnes() {
    val own = AdmonitionTitles(note = "Notatka")
    val titles =
      viewTitles {
        CompositionLocalProvider(LocalAdmonitionTitles provides provided) {
          EnrichedMarkdownText(markdown = "", admonitionTitles = own)
        }
      }

    assertEquals(own, titles)
  }

  private fun viewTitles(content: @Composable () -> Unit): AdmonitionTitles {
    lateinit var root: View
    composeRule.setContent {
      root = LocalView.current
      content()
    }
    composeRule.waitForIdle()
    val view = root.findDescendant<EnrichedMarkdown>()
    return EnrichedMarkdown::class.java
      .getDeclaredField("admonitionTitles")
      .apply { isAccessible = true }
      .get(view) as AdmonitionTitles
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
