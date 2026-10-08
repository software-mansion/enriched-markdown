@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.math

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.view.View
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.math.test.MathTestSupport.context
import com.swmansion.enriched.markdown.math.test.MathTestSupport.defaultStyle
import com.swmansion.enriched.markdown.math.test.MathTestSupport.latexMathDisplay
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PluginEvent
import com.swmansion.enriched.markdown.plugin.PluginEventSink
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
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
  fun inlineLayOutReportsTheFailureAndLeavesTheSourceToCoreInsteadOfThrowing() {
    val sink = RecordingSink()
    val span = MathInlineSpan.layOut(latex = "x^2", fontSize = 16f, textColor = Color.BLACK, onPluginEvent = sink)

    // Reported on the render thread, and there is no span to measure or draw.
    assertNull(span)
    val event = sink.events.single() as LatexError
    assertEquals("x^2", event.source)
    assertEquals(false, event.displayMode)
  }

  @Test
  fun midLineDisplayMathReportsItsFailureInDisplayMode() {
    val sink = RecordingSink()
    MathInlineSpan.layOut(latex = "x^2", fontSize = 16f, textColor = Color.BLACK, displayMode = true, onPluginEvent = sink)

    assertEquals(true, (sink.events.single() as LatexError).displayMode)
  }

  @Test
  fun blockPayloadReportsTheFailureAndTheViewDrawsItsSourceInsteadOfThrowing() {
    val sink = RecordingSink()
    val payload = MathBlockSegment().renderPayload(latexMathDisplay("E = mc^2"), defaultStyle, context, sink)

    // Reported on the render thread, where the payload is built for every render, so a reused
    // view does not have to report it again.
    assertNull(payload!!.renderer)
    val event = sink.events.single() as LatexError
    assertEquals("E = mc^2", event.source)
    assertEquals(true, event.displayMode)

    val view = MathContainerView(context, defaultStyle)
    view.applyPayload(payload)
    view.measure(
      View.MeasureSpec.makeMeasureSpec(720, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    view.layout(0, 0, view.measuredWidth, view.measuredHeight)
    view.draw(Canvas(Bitmap.createBitmap(720, 240, Bitmap.Config.ARGB_8888)))

    assertTrue("a fallback equation still occupies its block", view.measuredHeight > 0)
    assertEquals("the view reports nothing more", 1, sink.events.size)
  }
}
