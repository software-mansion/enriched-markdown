package com.swmansion.enriched.markdown

import android.content.Context
import android.text.Spannable
import android.util.TypedValue
import android.view.View
import android.view.ViewGroup
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.segments.MarkdownSegmentRenderer
import com.swmansion.enriched.markdown.segments.RenderedSegment
import com.swmansion.enriched.markdown.segments.splitASTIntoSegments
import com.swmansion.enriched.markdown.spans.HeadingSpan
import com.swmansion.enriched.markdown.spans.LinkSpan
import com.swmansion.enriched.markdown.test.MarkdownRenderAssertions.assertHasSpan
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.defaultStyle
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.blockquote
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.heading
import com.swmansion.enriched.markdown.test.TestAstFactory.link
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.strong
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28, 35])
class EnrichedMarkdownTest {
  private val context: Context = ApplicationProvider.getApplicationContext()

  private val plainParagraph = document(paragraph(text("Hello world")))

  private val mixedBlocks =
    document(
      heading(1, text("Title")),
      paragraph(text("A paragraph.")),
      unorderedList(listItem(paragraph(text("An item")))),
      blockquote(paragraph(text("A quote"))),
    )

  private val inlineFormattingWithLink =
    document(
      paragraph(
        text("Value: "),
        strong(text("42")),
        text(" via "),
        link("https://example.com", text("a link")),
      ),
    )

  /** Each document with a span it is known to render, or null when it carries no distinctive span. */
  private val documents =
    listOf<Pair<MarkdownASTNode, Class<*>?>>(
      plainParagraph to null,
      mixedBlocks to HeadingSpan::class.java,
      inlineFormattingWithLink to LinkSpan::class.java,
    )

  @Test
  fun exactlyOneChildAfterApplyingRenderedSegments() {
    documents.forEach { (document, _) ->
      val container = containerWithAppliedSegments(document)

      assertEquals(1, container.childCount)
      assertTrue(container.getChildAt(0) is EnrichedMarkdownInternalText)
    }
  }

  @Test
  fun childTextMatchesPreContainerRenderOutput() {
    documents.forEach { (document, spanClass) ->
      val container = containerWithAppliedSegments(document)
      val child = container.getChildAt(0) as EnrichedMarkdownInternalText

      assertEquals(render(document).toString(), child.text.toString())
      spanClass?.let { (child.text as Spannable).assertHasSpan(it) }
    }
  }

  @Test
  fun containerContributesNoStrayMarginToHeight() {
    documents.forEach { (document, _) ->
      val segments = MarkdownSegmentRenderer.render(splitASTIntoSegments(document), defaultStyle, context)
      val rendered = segments[0] as RenderedSegment.Text

      val standaloneTextView =
        EnrichedMarkdownInternalText(context).apply {
          setTextSize(TypedValue.COMPLEX_UNIT_PX, defaultStyle.paragraphStyle.fontSize)
          lastElementMarginBottom = rendered.lastElementMarginBottom
          setJustificationMode(rendered.needsJustify)
          applyStyledText(rendered.styledText)
        }
      layOut(standaloneTextView)

      val container = EnrichedMarkdown(context)
      container.applyRenderedSegments(segments)
      layOut(container)

      assertEquals(standaloneTextView.measuredHeight, container.measuredHeight)
    }
  }

  @Test
  fun prepareForViewReuseResetsTheContainer() {
    val container = containerWithAppliedSegments(mixedBlocks)
    assertEquals(1, container.childCount)

    container.prepareForViewReuse()

    assertEquals(0, container.childCount)
    assertEquals("", container.currentMarkdown)
  }

  @Test
  fun reconciliationKeepsTheChildInstanceWhenDocumentIsReappliedUnchanged() {
    val segments = MarkdownSegmentRenderer.render(splitASTIntoSegments(mixedBlocks), defaultStyle, context)
    val container = EnrichedMarkdown(context)

    container.applyRenderedSegments(segments)
    val firstChild = container.getChildAt(0)

    container.applyRenderedSegments(segments)
    val secondChild = container.getChildAt(0)

    assertSame(firstChild, secondChild)
  }

  private fun containerWithAppliedSegments(document: MarkdownASTNode): EnrichedMarkdown {
    val segments = MarkdownSegmentRenderer.render(splitASTIntoSegments(document), defaultStyle, context)
    val container = EnrichedMarkdown(context)
    container.applyRenderedSegments(segments)
    return container
  }

  private fun layOut(view: View) {
    view.layoutParams = ViewGroup.LayoutParams(CONTAINER_WIDTH, ViewGroup.LayoutParams.WRAP_CONTENT)
    view.measure(
      View.MeasureSpec.makeMeasureSpec(CONTAINER_WIDTH, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    view.layout(0, 0, view.measuredWidth, view.measuredHeight)
  }

  private companion object {
    const val CONTAINER_WIDTH = 720
  }
}
