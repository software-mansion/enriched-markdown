package com.swmansion.enriched.markdown

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.LeadingMarginSpan
import android.view.View.MeasureSpec
import android.view.ViewGroup
import android.widget.TextView
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.styles.ImageSourceOverride
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.utils.text.ImageCache
import com.swmansion.enriched.markdown.utils.text.span.prepareWidthAwareSpans
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

// Issue #1123: an image that fails to load used to stay an empty box. The URLs here have
// no loader, so the failure is reported synchronously while the span is constructed.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ImageSpanLoadFailureTest {
  private val context get() = RuntimeEnvironment.getApplication()

  private fun inlineSpan(
    url: String,
    alt: String,
    source: ImageSourceOverride? = null,
  ) = ImageSpan(context, url, styleConfig(), isInline = true, altText = alt, sourceOverride = source)

  private fun width(span: ImageSpan): Int = span.getSize(Paint(), "￼", 0, 1, null)

  @Test
  fun failedInlineImageGrowsToFitItsAltText() {
    assertTrue(width(inlineSpan("test://grows", "a diagram")) > INLINE_SIZE)
  }

  @Test
  fun failedInlineImageWithoutAltTextStaysSquare() {
    assertEquals(INLINE_SIZE, width(inlineSpan("test://no-alt", "")))
  }

  @Test
  fun failedInlineChipIsCapped() {
    assertEquals(CHIP_CAP, width(inlineSpan("test://capped", "a very long description ".repeat(20))))
  }

  // A deep list or a narrow component can leave less room than the cap: the chip shrinks to
  // the line, after leading margins, so its label is ellipsized instead of clipped.
  @Test
  fun failedInlineChipFitsTheLineAfterLeadingMargins() {
    val span = inlineSpan("test://narrow", "a very long description ".repeat(20))
    val view =
      EnrichedMarkdownInternalText(context).apply {
        layoutParams = ViewGroup.LayoutParams(NARROW_WIDTH, ViewGroup.LayoutParams.WRAP_CONTENT)
        applyStyledText(
          SpannableStringBuilder("￼").apply {
            setSpan(span, 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            setSpan(LeadingMarginSpan.Standard(MARGIN), 0, 1, Spanned.SPAN_INCLUSIVE_INCLUSIVE)
          },
        )
      }
    layOut(view, NARROW_WIDTH)

    assertEquals(NARROW_WIDTH - MARGIN, width(span))
    // The layout the view draws ends the chip at the view's edge, not past it.
    assertEquals(NARROW_WIDTH.toFloat(), view.layout.getLineRight(0), 0f)
  }

  // A table measures its columns at the widest a column can be, then lays the cells out at the
  // chosen width. A chip that failed after the table was laid out kept the narrow column's
  // width in the first pass, so its column never grew to fit the alt text.
  @Test
  fun columnPassWidensAChipButLeavesBlockImagesForTheRowPass() {
    val chip = inlineSpan("test://table-chip", "a very long description ".repeat(20))
    val block = ImageSpan(context, "test://table-block", styleConfig(), isInline = false, altText = "a diagram")
    val text =
      SpannableStringBuilder("￼ ￼").apply {
        setSpan(chip, 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        setSpan(block, 2, 3, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
      }
    prepareWidthAwareSpans(text, NARROW_WIDTH)

    prepareWidthAwareSpans(text, WIDTH, includeBlockImages = false)

    assertEquals(CHIP_CAP, width(chip))
    assertEquals(NARROW_WIDTH, block.drawable.bounds.width())
  }

  @Test
  fun spanBuiltAfterTheFailureStartsAsAChip() {
    val url = "http://localhost:1/built-later"
    ImageCache.markFailed(url)

    assertTrue(width(inlineSpan(url, "a diagram")) > INLINE_SIZE)
  }

  @Test
  fun imageThatLoadsAfterAFailureIsSquareAgain() {
    val url = "test://recovers"
    assertTrue(width(inlineSpan(url, "a diagram")) > INLINE_SIZE)

    ImageCache.putOriginal(url, Bitmap.createBitmap(10, 10, Bitmap.Config.ARGB_8888))

    assertEquals(INLINE_SIZE, width(inlineSpan(url, "a diagram")))
    assertFalse(ImageCache.hasFailed(url))
  }

  @Test
  fun emptyOverriddenSourceIsNotAFailure() {
    val source = ImageSourceOverride(uri = "", headers = emptyMap())

    assertEquals(INLINE_SIZE, width(inlineSpan("test://pending", "a diagram", source)))
    assertFalse(ImageCache.hasFailed(""))
  }

  @Test
  fun failedBlockImageKeepsItsBoxAndDrawsIt() {
    val span = ImageSpan(context, "test://block", styleConfig(), isInline = false, altText = "a diagram")
    val view =
      EnrichedMarkdownInternalText(context).apply {
        layoutParams = ViewGroup.LayoutParams(WIDTH, ViewGroup.LayoutParams.WRAP_CONTENT)
        applyStyledText(SpannableStringBuilder("￼").apply { setSpan(span, 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE) })
      }
    layOut(view)
    span.registerTextView(view)
    layOut(view)

    assertEquals(BLOCK_HEIGHT, view.layout.getLineBottom(0) - view.layout.getLineTop(0))

    val bitmap = Bitmap.createBitmap(WIDTH, BLOCK_HEIGHT, Bitmap.Config.ARGB_8888)
    span.draw(Canvas(bitmap), "￼", 0, 1, 0f, 0, 0, BLOCK_HEIGHT, Paint())
    assertTrue(bitmap.getPixel(WIDTH / 2, 2) != Color.TRANSPARENT)
  }

  // The failure can come before the view has a width. A plain TextView doesn't size the image
  // before its first layout, so the zero-wide box shares its line with the text after it until
  // the view is laid out again.
  @Test
  fun failedBlockImageIsLaidOutAgainOnceItsWidthIsKnown() {
    val span = ImageSpan(context, "test://width-later", styleConfig(), isInline = false, altText = "a diagram")
    val view =
      TextView(context).apply {
        layoutParams = ViewGroup.LayoutParams(WIDTH, ViewGroup.LayoutParams.WRAP_CONTENT)
        setText(
          SpannableStringBuilder("￼ after").apply { setSpan(span, 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE) },
          TextView.BufferType.SPANNABLE,
        )
      }
    layOut(view)
    assertEquals(1, view.layout.lineCount)

    span.registerTextView(view)
    layOut(view)

    assertEquals(2, view.layout.lineCount)
  }

  private fun layOut(
    view: TextView,
    width: Int = WIDTH,
  ) {
    view.measure(
      MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED),
    )
    view.layout(0, 0, view.measuredWidth, view.measuredHeight)
  }

  private companion object {
    const val INLINE_SIZE = 20
    const val CHIP_CAP = 200
    const val WIDTH = 400
    const val BLOCK_HEIGHT = 100
    const val NARROW_WIDTH = 120
    const val MARGIN = 30
  }
}
