package com.swmansion.enriched.markdown

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
import android.text.Layout
import android.util.TypedValue
import android.view.View
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.spans.registerWithSpans
import com.swmansion.enriched.markdown.styles.InlineImageStyle
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.image
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.utils.text.ImageCache
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
// Legacy graphics report zero font metrics, so the cap height this checks against would be zero.
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class InlineImagePlacementTest {
  private val context: Context = ApplicationProvider.getApplicationContext()

  // iOS centers an inline attachment on the font's cap height; Android used to sit the image on
  // the baseline, so an icon taller than the capitals stood above the text.
  @Test
  fun anInlineImageIsCenteredOnTheCapHeight() {
    val placement = placeInlineImage(MarkdownRenderTestSupport.defaultStyle)

    assertEquals(placement.capCenter, placement.imageCenter, 1f)
  }

  // iOS grows the line for an attachment taller than the text; Android kept the text's line
  // height, so the view clipped the image.
  @Test
  fun aTallInlineImageGrowsItsLine() {
    val defaultStyle = MarkdownRenderTestSupport.defaultStyle
    val size = defaultStyle.paragraphStyle.fontSize * 3
    val placement = placeInlineImage(MarkdownRenderTestSupport.styleWithInlineImage(InlineImageStyle(size)))

    assertEquals(size.toInt(), placement.imageRows.count())
    assertTrue(placement.imageRows.first >= placement.layout.getLineTop(0))
    assertTrue(placement.imageRows.last < placement.layout.getLineBottom(0))
    assertEquals(placement.capCenter, placement.imageCenter, 1f)
  }

  private class Placement(
    val layout: Layout,
    val imageRows: IntRange,
    val capCenter: Float,
  ) {
    val imageCenter: Float get() = (imageRows.first + imageRows.last + 1) / 2f
  }

  /** Draws a red inline image between text and finds the rows it painted. */
  private fun placeInlineImage(style: StyleConfig): Placement {
    val url = "test://inline-image-placement"
    ImageCache.putOriginal(url, Bitmap.createBitmap(32, 32, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.RED) })
    val rendered = render(document(paragraph(text("Inline "), image(url), text(" image"))), style)
    val textView = TextView(context)
    textView.setTextSize(TypedValue.COMPLEX_UNIT_PX, style.paragraphStyle.fontSize)
    textView.text = rendered
    textView.registerWithSpans(rendered)
    textView.measure(
      View.MeasureSpec.makeMeasureSpec(400, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    textView.layout(0, 0, 400, textView.measuredHeight)
    val layout = requireNotNull(textView.layout)

    val bitmap = Bitmap.createBitmap(400, textView.height, Bitmap.Config.ARGB_8888)
    layout.draw(Canvas(bitmap))
    val redRows =
      (0 until bitmap.height).filter { y ->
        (0 until bitmap.width).any { x ->
          val pixel = bitmap.getPixel(x, y)
          Color.alpha(pixel) > 0 && Color.red(pixel) > 128 && Color.green(pixel) < 64
        }
      }

    val capBounds = Rect()
    textView.paint.getTextBounds("H", 0, 1, capBounds)
    val capCenter = layout.getLineBaseline(0) - capBounds.height() / 2f
    return Placement(layout, redRows.first()..redRows.last(), capCenter)
  }
}
