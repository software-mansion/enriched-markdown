package com.swmansion.enriched.markdown

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.view.View
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.styles.InlineImageStyle
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.image
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.utils.text.ImageCache
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

// The corner radius is already in pixels; scaling it by the density again made a square a circle.
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28], qualifiers = "xxhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ImageCornerRadiusTest {
  private val context: Context = ApplicationProvider.getApplicationContext()

  @Test
  fun aSquareImageKeepsItsCornerRadius() {
    val radius = MarkdownRenderTestSupport.defaultStyle.imageStyle.borderRadius
    val size = radius * 5
    val url = "test://image-corner-radius"
    ImageCache.putOriginal(url, Bitmap.createBitmap(64, 64, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.RED) })
    val style = MarkdownRenderTestSupport.styleWithInlineImage(InlineImageStyle(size))
    val rendered = render(document(paragraph(text("A "), image(url), text(" B"))), style)

    val textView = TextView(context)
    textView.text = rendered
    textView.measure(
      View.MeasureSpec.makeMeasureSpec(WIDTH, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    textView.layout(0, 0, WIDTH, textView.measuredHeight)
    val bitmap = Bitmap.createBitmap(WIDTH, textView.height, Bitmap.Config.ARGB_8888)
    requireNotNull(textView.layout).draw(Canvas(bitmap))

    fun isRed(
      x: Int,
      y: Int,
    ): Boolean {
      val pixel = bitmap.getPixel(x, y)
      return Color.alpha(pixel) > 200 && Color.red(pixel) > 200 && Color.green(pixel) < 64
    }
    val left = (0 until WIDTH).first { x -> (0 until bitmap.height).any { y -> isRed(x, y) } }
    val top = (0 until bitmap.height).first { y -> (0 until WIDTH).any { x -> isRed(x, y) } }

    assertFalse(isRed(left, top))
    val inset = (radius / 2).toInt()
    assertTrue(isRed(left + inset, top + inset))
  }

  private companion object {
    const val WIDTH = 1200
  }
}
