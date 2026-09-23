package com.swmansion.enriched.markdown

import android.text.Layout
import android.text.Spannable
import android.text.style.AlignmentSpan
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.styles.TextAlignment
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleWithTextAlign
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.heading
import com.swmansion.enriched.markdown.test.TestAstFactory.lineBreak
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * The layout only aligns relative to a paragraph's direction, so LEFT and RIGHT are resolved
 * against each paragraph's direction to pin a side.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class TextAlignmentRendererTest {
  private val ltr = "hello"
  private val rtl = "שלום"

  @Test
  fun leftPinsTheLeftSideInBothDirections() {
    assertEquals(Layout.Alignment.ALIGN_NORMAL, alignmentOf(ltr, TextAlignment.LEFT))
    assertEquals(Layout.Alignment.ALIGN_OPPOSITE, alignmentOf(rtl, TextAlignment.LEFT))
  }

  @Test
  fun rightPinsTheRightSideInBothDirections() {
    assertEquals(Layout.Alignment.ALIGN_OPPOSITE, alignmentOf(ltr, TextAlignment.RIGHT))
    assertEquals(Layout.Alignment.ALIGN_NORMAL, alignmentOf(rtl, TextAlignment.RIGHT))
  }

  @Test
  fun startAndEndFollowTheReadingDirection() {
    assertNull(alignmentOf(rtl, TextAlignment.START))
    assertNull(alignmentOf(rtl, TextAlignment.AUTO))
    assertEquals(Layout.Alignment.ALIGN_OPPOSITE, alignmentOf(rtl, TextAlignment.END))
    assertEquals(Layout.Alignment.ALIGN_CENTER, alignmentOf(rtl, TextAlignment.CENTER))
  }

  @Test
  fun resolvesEachLineOfAParagraphOnItsOwn() {
    val rendered =
      render(document(paragraph(text(ltr), lineBreak(), text(rtl))), styleWithTextAlign(TextAlignment.LEFT))

    assertEquals(Layout.Alignment.ALIGN_NORMAL, rendered.alignmentOver(ltr))
    assertEquals(Layout.Alignment.ALIGN_OPPOSITE, rendered.alignmentOver(rtl))
  }

  @Test
  fun resolvesHeadings() {
    val rendered = render(document(heading(1, text(rtl))), styleWithTextAlign(TextAlignment.RIGHT))

    assertEquals(Layout.Alignment.ALIGN_NORMAL, rendered.alignmentOver(rtl))
  }

  @Test
  // An RTL locale gives an RTL layout direction.
  @Config(qualifiers = "ar")
  fun textWithoutAStrongCharacterFollowsTheLayoutDirection() {
    assertEquals(Layout.Alignment.ALIGN_OPPOSITE, alignmentOf("123", TextAlignment.LEFT))
  }

  private fun alignmentOf(
    content: String,
    textAlign: TextAlignment,
  ): Layout.Alignment? = render(document(paragraph(text(content))), styleWithTextAlign(textAlign)).alignmentOver(content)

  private fun Spannable.alignmentOver(text: String): Layout.Alignment? {
    val start = toString().indexOf(text)
    assertTrue("Expected rendered text to contain \"$text\"", start >= 0)
    val spans = getSpans(start, start + text.length, AlignmentSpan::class.java)
    assertTrue("Expected at most one AlignmentSpan over \"$text\", got ${spans.size}", spans.size <= 1)
    return spans.firstOrNull()?.alignment
  }
}
