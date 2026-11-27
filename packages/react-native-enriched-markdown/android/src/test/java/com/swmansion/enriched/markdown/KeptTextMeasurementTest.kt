package com.swmansion.enriched.markdown

import android.content.Context
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.SpannedString
import android.text.TextPaint
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.facebook.yoga.YogaMeasureOutput
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.spans.LinkPillSpan
import com.swmansion.enriched.markdown.styles.LinkPillContent
import com.swmansion.enriched.markdown.styles.LinkPillStyle
import com.swmansion.enriched.markdown.styles.LinkVariantEntry
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.utils.text.span.prepareWidthAwareSpans
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

// #1147: image spans size themselves to the width they are laid out at, in fields the view draws
// from. A line-clamped CommonMark view hands MeasurementStore.store a copy of its text that shares
// its spans, and a Yoga measure at another width laid it out again off the main thread; and store
// itself lays the view's text out at Yoga's last measured width, which a flex row's basis can make
// one the view doesn't draw at.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class KeptTextMeasurementTest {
  private val context: Context get() = RuntimeEnvironment.getApplication()
  private val viewId = 51147
  private val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 40f }

  @Before
  fun setUp() = DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(context)

  @After
  fun release() = MeasurementStore.release(viewId)

  @Test
  fun aMeasureAtAnotherWidthLeavesTheViewsImageAlone() {
    val image = ImageSpan(context, "", styleConfig(image = mapOf("aspectRatio" to 2.0, "resizeMode" to "contain")))
    // What a clamped view holds: TextView copies the rendered text, sharing its spans.
    val text =
      SpannedString(
        SpannableStringBuilder("\uFFFC\nwords after the image").apply { setSpan(image, 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE) },
      )
    // The view lays it out at its width, then hands it to the store.
    prepareWidthAwareSpans(text, VIEW_WIDTH)
    val shown = imageSize(image, text)
    MeasurementStore.recordMeasured(viewId, VIEW_WIDTH.toFloat(), YogaMeasureOutput.make(VIEW_WIDTH.toFloat(), 600f))
    MeasurementStore.store(viewId, text, paint)

    // Yoga measures at another width, on its own thread.
    MeasurementStore.measureKeptTextAtWidth(viewId, OTHER_WIDTH.toFloat())

    assertEquals(shown, imageSize(image, text))
  }

  // A flex row measures its basis, wider than the width the view lays out at.
  @Test
  fun storingAtAWidthTheViewDoesntLayOutAtLeavesItsImageAlone() {
    val image = ImageSpan(context, "", styleConfig(image = mapOf("aspectRatio" to 2.0, "resizeMode" to "contain")))
    val text =
      SpannedString(
        SpannableStringBuilder("\uFFFC\nwords after the image").apply { setSpan(image, 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE) },
      )
    prepareWidthAwareSpans(text, OTHER_WIDTH)
    val shown = imageSize(image, text)
    MeasurementStore.recordMeasured(viewId, VIEW_WIDTH.toFloat(), YogaMeasureOutput.make(VIEW_WIDTH.toFloat(), 600f))

    MeasurementStore.store(viewId, text, paint, viewWidthPx = OTHER_WIDTH)

    assertEquals(shown, imageSize(image, text))
  }

  // The store's layout runs on the main thread, so it writes the width limit the view's pill draws with.
  @Test
  fun storingAtAWidthTheViewDoesntLayOutAtLeavesItsPillAsDrawn() {
    val label = List(40) { "word$it" }.joinToString(" ")
    val pill =
      LinkPillSpan(
        LinkVariantEntry("", Color.BLACK, false, Color.TRANSPARENT, pill = LinkPillStyle()),
        Typeface.DEFAULT,
        14f,
        label,
        context,
        LinkPillContent(),
      )
    val text = SpannedString(SpannableStringBuilder(label).apply { setSpan(pill, 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE) })
    // The view lays its text out at its width, which reserves the pill's box.
    prepareWidthAwareSpans(text, OTHER_WIDTH)
    val shown = drawnPillWidth(pill, text)
    assertTrue("$shown > $OTHER_WIDTH", shown <= OTHER_WIDTH)
    MeasurementStore.recordMeasured(viewId, VIEW_WIDTH.toFloat(), YogaMeasureOutput.make(VIEW_WIDTH.toFloat(), 60f))

    MeasurementStore.store(viewId, text, paint, viewWidthPx = OTHER_WIDTH)

    // What the view draws next, without laying the pill out again (getSize would reserve it anew).
    assertEquals(shown, drawnPillWidth(pill, text, layOut = false), 0.5f)
  }

  // The width of the box [pill] draws, after a layout at its limit unless [layOut] is false.
  private fun drawnPillWidth(
    pill: LinkPillSpan,
    text: CharSequence,
    layOut: Boolean = true,
  ): Float {
    if (layOut) pill.getSize(paint, text, 0, text.length, null)
    var width = 0f
    val canvas =
      object : android.graphics.Canvas(android.graphics.Bitmap.createBitmap(2000, 200, android.graphics.Bitmap.Config.ARGB_8888)) {
        override fun drawRoundRect(
          rect: android.graphics.RectF,
          rx: Float,
          ry: Float,
          p: Paint,
        ) {
          width = maxOf(width, rect.width())
        }
      }
    pill.draw(canvas, text, 0, text.length, 0f, 0, 40, 60, paint)
    return width
  }

  @Test
  fun textWithoutWidthAwareSpansIsStillMeasuredFromWhatTheViewShows() {
    val text = SpannedString("only words, nothing sized to the width")
    MeasurementStore.recordMeasured(viewId, VIEW_WIDTH.toFloat(), YogaMeasureOutput.make(VIEW_WIDTH.toFloat(), 60f))
    MeasurementStore.store(viewId, text, paint)

    assertNotNull(MeasurementStore.measureKeptTextAtWidth(viewId, OTHER_WIDTH.toFloat()))
  }

  @Test
  fun textWithAnImageIsRenderedAgainForAnotherWidth() {
    val image = ImageSpan(context, "", styleConfig())
    val text = SpannedString(SpannableStringBuilder("\uFFFC").apply { setSpan(image, 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE) })
    MeasurementStore.recordMeasured(viewId, VIEW_WIDTH.toFloat(), YogaMeasureOutput.make(VIEW_WIDTH.toFloat(), 600f))
    MeasurementStore.store(viewId, text, paint)

    assertNull(MeasurementStore.measureKeptTextAtWidth(viewId, OTHER_WIDTH.toFloat()))
  }

  private fun imageSize(
    image: ImageSpan,
    text: CharSequence,
  ): Pair<Int, Int> = image.getSize(paint, text, 0, 1, null) to image.drawable.bounds.height()

  private companion object {
    const val VIEW_WIDTH = 1000
    const val OTHER_WIDTH = 600
  }
}
