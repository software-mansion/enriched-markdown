package com.swmansion.enriched.markdown.compose

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.ui.AbsoluteAlignment
import androidx.compose.ui.Alignment
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.compose.test.ComposeStyleTestSupport
import com.swmansion.enriched.markdown.styles.TableAlignment
import com.swmansion.enriched.markdown.styles.TextAlignment
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * The DSL takes Compose vocabulary ([TextAlign], [Alignment.Horizontal], [TextDecoration],
 * [PaddingValues]) and maps it onto the types the text layer understands.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class MarkdownStyleComposeTypesTest {
  @get:Rule
  val composeRule = createComposeRule()

  private fun resolveContext(): StyleResolveContext {
    var resolveContext: StyleResolveContext? = null
    composeRule.setContent { resolveContext = ComposeStyleTestSupport.rememberResolveContext() }
    composeRule.waitForIdle()
    return requireNotNull(resolveContext)
  }

  @Test
  fun mapsTextAlignOntoTheTextLayerAlignment() {
    val context = resolveContext()

    assertEquals(
      TextAlignment.CENTER,
      markdownStyle { paragraph { textAlign = TextAlign.Center } }.resolve(context).paragraphStyle.textAlign,
    )
    assertEquals(
      TextAlignment.JUSTIFY,
      markdownStyle { paragraph { textAlign = TextAlign.Justify } }.resolve(context).paragraphStyle.textAlign,
    )
    assertEquals(
      TextAlignment.RIGHT,
      markdownStyle { h1 { textAlign = TextAlign.End } }.resolve(context).headingStyles[1]?.textAlign,
    )
  }

  @Test
  fun mapsLinkTextDecorationOntoUnderline() {
    val context = resolveContext()

    assertTrue(
      markdownStyle { link { textDecoration = TextDecoration.Underline } }.resolve(context).linkStyle.underline,
    )
    assertFalse(
      markdownStyle { link { textDecoration = TextDecoration.None } }.resolve(context).linkStyle.underline,
    )
  }

  @Test
  fun mapsTableAlignmentOntoTheTablePlacement() {
    val context = resolveContext()

    assertEquals(
      TableAlignment.AUTO,
      markdownStyle { table { alignment = Alignment.Start } }.resolve(context).tableStyle.align,
    )
    assertEquals(
      TableAlignment.LEFT,
      markdownStyle { table { alignment = AbsoluteAlignment.Left } }.resolve(context).tableStyle.align,
    )
    assertEquals(
      TableAlignment.RIGHT,
      markdownStyle { table { alignment = Alignment.End } }.resolve(context).tableStyle.align,
    )
  }

  @Test
  fun resolvesUniformPaddingValues() {
    val context = resolveContext()
    val density = ComposeStyleTestSupport.testDensity

    val resolved = markdownStyle { codeBlock { padding = PaddingValues(12.dp) } }.resolve(context)

    assertEquals(with(density) { 12.dp.toPx() }, resolved.codeBlockStyle.padding, 0.01f)
  }

  @Test
  fun rejectsNonUniformPaddingValues() {
    val context = resolveContext()
    val style = markdownStyle { codeBlock { padding = PaddingValues(horizontal = 12.dp, vertical = 4.dp) } }

    val error = assertThrows(IllegalArgumentException::class.java) { style.resolve(context) }

    assertTrue(error.message.orEmpty().contains("codeBlock.padding"))
  }
}
