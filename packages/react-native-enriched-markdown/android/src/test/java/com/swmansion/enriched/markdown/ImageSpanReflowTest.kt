package com.swmansion.enriched.markdown

import android.graphics.Bitmap
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.view.View.MeasureSpec
import android.view.ViewGroup
import android.widget.TextView
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.utils.text.ImageCache
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

// Issue #932: a block image with maxHeight starts at maxHeight and shrinks to its
// fitted height once the view's width is known. The TextView must rebuild its Layout
// then, or the image line keeps maxHeight and the text after it overflows the component.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ImageSpanReflowTest {
  @Test
  fun imageLineShrinksToTheFittedHeightOnceTheWidthIsKnown() {
    val context = RuntimeEnvironment.getApplication()

    ImageCache.putOriginal(ImageCache.requestKey(URL, emptyMap()), Bitmap.createBitmap(100, 50, Bitmap.Config.ARGB_8888))
    val span = ImageSpan(context, URL, styleConfig(image = mapOf("maxHeight" to MAX_HEIGHT.toDouble(), "resizeMode" to "contain")))

    val view =
      EnrichedMarkdownInternalText(context).apply {
        layoutParams = ViewGroup.LayoutParams(WIDTH, ViewGroup.LayoutParams.WRAP_CONTENT)
        applyStyledText(SpannableStringBuilder("￼\nafter").apply { setSpan(span, 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE) })
      }

    layOut(view)
    assertEquals(MAX_HEIGHT, imageLineHeight(view))

    span.registerTextView(view)

    layOut(view)
    assertEquals(WIDTH / 2, imageLineHeight(view))
  }

  private fun layOut(view: TextView) {
    view.measure(
      MeasureSpec.makeMeasureSpec(WIDTH, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED),
    )
    view.layout(0, 0, view.measuredWidth, view.measuredHeight)
  }

  private fun imageLineHeight(view: TextView): Int = view.layout.getLineBottom(0) - view.layout.getLineTop(0)

  private companion object {
    const val URL = "test://issue-932"
    const val WIDTH = 400
    const val MAX_HEIGHT = 300
  }
}
