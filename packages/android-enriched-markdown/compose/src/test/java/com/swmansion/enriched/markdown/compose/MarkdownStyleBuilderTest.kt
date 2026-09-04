package com.swmansion.enriched.markdown.compose

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.compose.test.ComposeStyleTestSupport
import com.swmansion.enriched.markdown.styles.StyleConfig
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class MarkdownStyleBuilderTest {
  @get:Rule
  val composeRule = createComposeRule()

  @Test
  fun resolvesParagraphStyleOverrides() {
    var resolveContext: com.swmansion.enriched.markdown.compose.style.StyleResolveContext? = null

    composeRule.setContent {
      resolveContext = ComposeStyleTestSupport.rememberResolveContext()
    }
    composeRule.waitForIdle()

    val style =
      markdownStyle {
        paragraph {
          fontSize = 16.sp
          color = Color(0xFF112233)
        }
      }

    val resolved = style.resolve(requireNotNull(resolveContext))
    val paragraph = resolved.paragraphStyle

    assertEquals(with(ComposeStyleTestSupport.testDensity) { 16.sp.toPx() }, paragraph.fontSize, 0.01f)
    assertEquals(0xFF112233.toInt(), paragraph.color)
  }

  @Test
  fun resolvesTaskListStyleOverrides() {
    var resolveContext: com.swmansion.enriched.markdown.compose.style.StyleResolveContext? = null

    composeRule.setContent {
      resolveContext = ComposeStyleTestSupport.rememberResolveContext()
    }
    composeRule.waitForIdle()

    val style =
      markdownStyle {
        taskList {
          checkedColor = Color(0xFF34C759)
          checkboxSize = 18.dp
          checkedTextColor = Color(0xFF8E8E93)
          checkedStrikethrough = true
        }
      }

    val resolved = style.resolve(requireNotNull(resolveContext))
    val taskList = resolved.taskListStyle
    val defaults = StyleConfig.default(ComposeStyleTestSupport.context).taskListStyle

    assertEquals(0xFF34C759.toInt(), taskList.checkedColor)
    assertEquals(with(ComposeStyleTestSupport.testDensity) { 18.dp.toPx() }, taskList.checkboxSize, 0.01f)
    assertEquals(0xFF8E8E93.toInt(), taskList.checkedTextColor)
    assertEquals(true, taskList.checkedStrikethrough)
    assertEquals(defaults.borderColor, taskList.borderColor)
    assertEquals(defaults.checkmarkColor, taskList.checkmarkColor)
  }
}
