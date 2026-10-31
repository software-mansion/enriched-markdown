package com.swmansion.enriched.markdown.compose

import android.view.View
import android.view.ViewGroup
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.EnrichedMarkdown
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/** The style [EnrichedMarkdownText] hands its view. The markdown is left empty: rendering it needs the native parser. */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class StyleResolutionViewTest {
  @get:Rule
  val composeRule = createComposeRule()

  private val first = Color(0xFF111111)
  private val second = Color(0xFFEEEEEE)

  private fun styled(color: Color) = markdownStyle { paragraph { this.color = color } }

  @Test
  fun theViewHasTheStyleWhenItIsFirstComposed() {
    val composed = mutableListOf<Int>()

    composeRule.setContent {
      val root = LocalView.current
      EnrichedMarkdownText(markdown = "", style = styled(first))
      SideEffect {
        root.descendants().filterIsInstance<EnrichedMarkdown>().firstOrNull()?.let {
          composed += it.markdownStyle.paragraphStyle.color
        }
      }
    }

    assertEquals(first.toArgb(), composed.first())
  }

  @Test
  fun aStyleCanBeSwitchedAwayFromAndBack() {
    lateinit var root: View
    var style by mutableStateOf(styled(first))

    composeRule.setContent {
      root = LocalView.current
      EnrichedMarkdownText(markdown = "", style = style)
    }
    composeRule.waitForIdle()
    val view = root.descendants().filterIsInstance<EnrichedMarkdown>().first()

    style = styled(second)
    composeRule.waitForIdle()
    assertEquals(second.toArgb(), view.markdownStyle.paragraphStyle.color)

    style = styled(first)
    composeRule.waitForIdle()
    assertEquals(first.toArgb(), view.markdownStyle.paragraphStyle.color)
  }

  private fun View.descendants(): Sequence<View> =
    sequence {
      yield(this@descendants)
      if (this@descendants is ViewGroup) {
        for (i in 0 until childCount) yieldAll(getChildAt(i).descendants())
      }
    }
}
