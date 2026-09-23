package com.swmansion.enriched.markdown.math

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.View
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.math.test.MathTestSupport.context
import com.swmansion.enriched.markdown.math.test.MathTestSupport.defaultStyle
import com.swmansion.enriched.markdown.plugin.PluginEvent
import com.swmansion.enriched.markdown.plugin.PluginEventSink
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * What happens when the RaTeX engine cannot run at all.
 *
 * RaTeX ships no native library for every ABI - 32-bit x86 has none - and a JVM test host has none
 * either, so these tests reach the engine for real and it fails for the same reason it would on an
 * unsupported device. That failure is a `LinkageError`, not an `Exception`, and it must still leave
 * the reader with the source of the equation rather than taking the view or the render thread down.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class RaTeXUnavailableTest {
  private class RecordingSink : PluginEventSink {
    val events = mutableListOf<PluginEvent>()

    override fun emit(event: PluginEvent) {
      events += event
    }
  }

  @Test
  fun inlineSpanMeasuresAndDrawsItsSourceInsteadOfThrowing() {
    val sink = RecordingSink()
    val span = MathInlineSpan(latex = "x^2", fontSize = 16f, textColor = Color.BLACK, onPluginEvent = sink)
    val paint = Paint().apply { textSize = 16f }

    val width = span.getSize(paint, "￼", 0, 1, null)
    span.draw(Canvas(Bitmap.createBitmap(64, 64, Bitmap.Config.ARGB_8888)), "￼", 0, 1, 0f, 0, 16, 32, paint)

    assertTrue("the fallback source needs room to draw in", width > 0)
    val event = sink.events.single() as LatexErrorEvent
    assertEquals("x^2", event.source)
    assertEquals(false, event.displayMode)
  }

  @Test
  fun blockViewMeasuresAndDrawsItsSourceInsteadOfThrowing() {
    val sink = RecordingSink()
    val view = MathContainerView(context, defaultStyle).apply { onPluginEvent = sink }

    view.applyLatex("E = mc^2")
    view.measure(
      View.MeasureSpec.makeMeasureSpec(720, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    view.layout(0, 0, view.measuredWidth, view.measuredHeight)
    view.draw(Canvas(Bitmap.createBitmap(720, 240, Bitmap.Config.ARGB_8888)))

    assertTrue("a fallback equation still occupies its block", view.measuredHeight > 0)
    val event = sink.events.single() as LatexErrorEvent
    assertEquals("E = mc^2", event.source)
    assertEquals(true, event.displayMode)
  }

  @Test
  fun aSecondFailureOfTheSameSpanIsNotReportedTwice() {
    val sink = RecordingSink()
    val span = MathInlineSpan(latex = "x^2", fontSize = 16f, textColor = Color.BLACK, onPluginEvent = sink)
    val paint = Paint().apply { textSize = 16f }

    span.getSize(paint, "￼", 0, 1, null)
    span.getSize(paint, "￼", 0, 1, null)

    assertEquals(1, sink.events.size)
  }
}
