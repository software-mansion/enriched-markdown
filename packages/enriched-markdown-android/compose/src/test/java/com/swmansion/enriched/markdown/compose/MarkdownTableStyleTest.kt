package com.swmansion.enriched.markdown.compose

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.compose.test.ComposeStyleTestSupport
import com.swmansion.enriched.markdown.styles.TableAlignment
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class MarkdownTableStyleTest {
  @get:Rule
  val composeRule = createComposeRule()

  private fun resolveContext(): StyleResolveContext {
    var resolveContext: StyleResolveContext? = null
    composeRule.setContent { resolveContext = ComposeStyleTestSupport.rememberResolveContext() }
    composeRule.waitForIdle()
    return requireNotNull(resolveContext)
  }

  @Test
  fun resolvesTableStyleOverrides() {
    val context = resolveContext()
    val density = ComposeStyleTestSupport.testDensity

    val resolved =
      markdownStyle {
        table {
          fontSize = 15.sp
          color = Color(0xFF112233)
          headerBackgroundColor = Color(0xFF445566)
          borderWidth = 2.dp
          cornerRadius = 10.dp
          cellPaddingHorizontal = 14.dp
          align = TableAlignment.CENTER
        }
      }.resolve(context)

    val table = resolved.tableStyle
    assertEquals(with(density) { 15.sp.toPx() }, table.fontSize, 0.01f)
    assertEquals(0xFF112233.toInt(), table.color)
    assertEquals(0xFF445566.toInt(), table.headerBackgroundColor)
    assertEquals(with(density) { 2.dp.toPx() }, table.borderWidth, 0.01f)
    assertEquals(with(density) { 10.dp.toPx() }, table.borderRadius, 0.01f)
    assertEquals(with(density) { 14.dp.toPx() }, table.cellPaddingHorizontal, 0.01f)
    assertEquals(TableAlignment.CENTER, table.align)
  }

  @Test
  fun resolvesTableHorizontalOverflow() {
    val context = resolveContext()
    val density = ComposeStyleTestSupport.testDensity

    val resolved = markdownStyle { table { horizontalOverflow = 24.dp } }.resolve(context)

    assertEquals(with(density) { 24.dp.toPx() }, resolved.tableStyle.horizontalOverflow, 0.01f)
  }

  @Test
  fun keepsUntouchedTableValuesFromTheDefaults() {
    val context = resolveContext()
    val defaults = MarkdownStyle.Default.resolve(context).tableStyle

    val resolved = markdownStyle { table { color = Color.Red } }.resolve(context)

    assertEquals(defaults.borderColor, resolved.tableStyle.borderColor)
    assertEquals(defaults.cellPaddingVertical, resolved.tableStyle.cellPaddingVertical, 0.01f)
    assertEquals(defaults.marginBottom, resolved.tableStyle.marginBottom, 0.01f)
  }

  @Test
  fun rebuildsTableTypefacesWhenTheTableStyleIsPatched() {
    val context = resolveContext()

    val resolved = markdownStyle { table { fontFamily = FontFamily.Monospace } }.resolve(context)

    assertNotNull(resolved.tableTypeface)
    assertNotNull(resolved.tableHeaderTypeface)
  }
}
