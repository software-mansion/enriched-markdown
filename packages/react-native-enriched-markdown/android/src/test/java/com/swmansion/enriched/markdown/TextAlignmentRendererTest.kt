package com.swmansion.enriched.markdown

import android.text.Layout
import android.text.Spannable
import android.text.style.AlignmentSpan
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.test.TestAstFactory.heading
import com.swmansion.enriched.markdown.test.TestAstFactory.lineBreak
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * The layout only aligns relative to a paragraph's direction, so `left` and `right` are resolved
 * against each paragraph's direction to pin a physical side, as on iOS.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class TextAlignmentRendererTest {
  private val ltr = "hello"
  private val rtl = "שלום"

  @Test
  fun leftPinsTheLeftSideInBothDirections() {
    assertEquals(Layout.Alignment.ALIGN_NORMAL, alignmentOf(ltr, "left"))
    assertEquals(Layout.Alignment.ALIGN_OPPOSITE, alignmentOf(rtl, "left"))
  }

  @Test
  fun rightPinsTheRightSideInBothDirections() {
    assertEquals(Layout.Alignment.ALIGN_OPPOSITE, alignmentOf(ltr, "right"))
    assertEquals(Layout.Alignment.ALIGN_NORMAL, alignmentOf(rtl, "right"))
  }

  @Test
  fun autoJustifyAndCenterDoNotDependOnTheDirection() {
    assertNull(alignmentOf(rtl, "auto"))
    assertNull(alignmentOf(ltr, "auto"))
    assertNull(alignmentOf(rtl, "justify"))
    assertEquals(Layout.Alignment.ALIGN_CENTER, alignmentOf(rtl, "center"))
    assertEquals(Layout.Alignment.ALIGN_CENTER, alignmentOf(ltr, "center"))
  }

  @Test
  fun resolvesEachLineOfAParagraphOnItsOwn() {
    val rendered = render(styleConfig(textAlign = "left"), paragraph(text(ltr), lineBreak(), text(rtl)))

    assertEquals(Layout.Alignment.ALIGN_NORMAL, rendered.alignmentOver(ltr))
    assertEquals(Layout.Alignment.ALIGN_OPPOSITE, rendered.alignmentOver(rtl))
  }

  @Test
  fun resolvesHeadings() {
    val rendered = render(styleConfig(textAlign = "right"), heading(1, text(rtl)), heading(1, text(ltr)))

    assertEquals(Layout.Alignment.ALIGN_NORMAL, rendered.alignmentOver(rtl))
    assertEquals(Layout.Alignment.ALIGN_OPPOSITE, rendered.alignmentOver(ltr))
  }

  @Test
  // An RTL locale gives an RTL layout direction.
  @Config(qualifiers = "ar")
  fun textWithoutAStrongCharacterFollowsTheLayoutDirection() {
    assertEquals(Layout.Alignment.ALIGN_OPPOSITE, alignmentOf("123", "left"))
  }

  private fun alignmentOf(
    content: String,
    textAlign: String,
  ): Layout.Alignment? = render(styleConfig(textAlign = textAlign), paragraph(text(content))).alignmentOver(content)

  private fun Spannable.alignmentOver(text: String): Layout.Alignment? {
    val start = toString().indexOf(text)
    assertTrue("Expected rendered text to contain \"$text\"", start >= 0)
    val spans = getSpans(start, start + text.length, AlignmentSpan::class.java)
    assertTrue("Expected at most one AlignmentSpan over \"$text\", got ${spans.size}", spans.size <= 1)
    return spans.firstOrNull()?.alignment
  }
}
