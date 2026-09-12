package com.swmansion.enriched.markdown.compose

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertSame
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class MarkdownThemeTest {
  @get:Rule
  val composeRule = createComposeRule()

  private val outerStyle =
    markdownStyle {
      link { color = Color.Red }
    }

  private val innerStyle =
    markdownStyle {
      link { color = Color.Blue }
    }

  @Test
  fun nestedMarkdownThemeUsesInnerStyle() {
    var capturedStyle: MarkdownStyle? = null

    composeRule.setContent {
      MarkdownTheme(style = outerStyle) {
        MarkdownTheme(style = innerStyle) {
          capturedStyle = MarkdownTheme.style
        }
      }
    }

    assertSame(innerStyle, capturedStyle)
  }
}
