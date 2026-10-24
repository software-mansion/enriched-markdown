package com.swmansion.enriched.markdown.compose

import androidx.compose.ui.AbsoluteAlignment
import androidx.compose.ui.Alignment
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.compose.test.ComposeStyleTestSupport
import com.swmansion.enriched.markdown.styles.TableAlignment
import com.swmansion.enriched.markdown.styles.TextAlignment
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * The DSL takes Compose vocabulary ([TextAlign], [Alignment.Horizontal], [TextDecoration]) and
 * maps it onto the types the text layer understands.
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
      TextAlignment.START,
      markdownStyle { paragraph { textAlign = TextAlign.Start } }.resolve(context).paragraphStyle.textAlign,
    )
    assertEquals(
      TextAlignment.LEFT,
      markdownStyle { paragraph { textAlign = TextAlign.Left } }.resolve(context).paragraphStyle.textAlign,
    )
    assertEquals(
      TextAlignment.END,
      markdownStyle { h1 { textAlign = TextAlign.End } }.resolve(context).headingStyles[1]?.textAlign,
    )
    assertEquals(
      TextAlignment.RIGHT,
      markdownStyle { h1 { textAlign = TextAlign.Right } }.resolve(context).headingStyles[1]?.textAlign,
    )
  }

  @Test
  fun leavesTextAlignUntouchedWhenUnspecified() {
    val context = resolveContext()

    assertEquals(
      markdownStyle {}.resolve(context).paragraphStyle.textAlign,
      markdownStyle { paragraph { textAlign = TextAlign.Unspecified } }.resolve(context).paragraphStyle.textAlign,
    )
  }

  @Test
  fun mapsLinkTextDecorationOntoTheLinkLines() {
    val context = resolveContext()

    val underline = markdownStyle { link { textDecoration = TextDecoration.Underline } }.resolve(context).linkStyle
    assertTrue(underline.underline)
    assertFalse(underline.strikethrough)

    val lineThrough = markdownStyle { link { textDecoration = TextDecoration.LineThrough } }.resolve(context).linkStyle
    assertFalse(lineThrough.underline)
    assertTrue(lineThrough.strikethrough)

    val both =
      markdownStyle {
        link { textDecoration = TextDecoration.combine(listOf(TextDecoration.Underline, TextDecoration.LineThrough)) }
      }.resolve(context).linkStyle
    assertTrue(both.underline)
    assertTrue(both.strikethrough)

    val none = markdownStyle { link { textDecoration = TextDecoration.None } }.resolve(context).linkStyle
    assertFalse(none.underline)
    assertFalse(none.strikethrough)
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
      TableAlignment.END,
      markdownStyle { table { alignment = Alignment.End } }.resolve(context).tableStyle.align,
    )
    assertEquals(
      TableAlignment.RIGHT,
      markdownStyle { table { alignment = AbsoluteAlignment.Right } }.resolve(context).tableStyle.align,
    )
  }
}
