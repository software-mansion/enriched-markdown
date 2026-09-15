package com.swmansion.enriched.markdown

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.text.SpannableString
import android.util.TypedValue
import android.view.View
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.SpoilerSpan
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlay
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlayDrawer
import com.swmansion.enriched.markdown.spoiler.computeSegmentRect
import com.swmansion.enriched.markdown.styles.SpoilerStyle
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.spoiler
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.shadows.ShadowSystemClock
import java.time.Duration

/**
 * Covers the geometry the overlay paints and the state machine a reveal walks through.
 *
 * Scope note: the particle field is driven by [android.view.Choreographer], which Robolectric only
 * advances through a paused looper, and its output is random by design. The animation *timing* is
 * therefore deliberately out of scope — what is asserted here is the static draw (one rect per
 * line of the span, in the styled color) and the transitions a span makes as it is revealed.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
// Robolectric's legacy graphics report zero font metrics, which collapses every segment rect to
// zero height; the native runtime lays text out for real, which is what this geometry needs.
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SpoilerPaintingTest {
  private val context: Context = ApplicationProvider.getApplicationContext()

  private companion object {
    const val WIDTH = 400
    const val OVERLAY = 0xFF884422.toInt()
  }

  /** A [Canvas] that remembers the shapes drawn onto it, with the color each was painted in. */
  private class RecordingCanvas(
    bitmap: Bitmap,
  ) : Canvas(bitmap) {
    val roundRects = mutableListOf<Pair<RectF, Int>>()
    val rects = mutableListOf<Pair<RectF, Int>>()

    override fun drawRoundRect(
      rect: RectF,
      rx: Float,
      ry: Float,
      paint: Paint,
    ) {
      roundRects.add(RectF(rect) to paint.color)
      super.drawRoundRect(rect, rx, ry, paint)
    }

    override fun drawRect(
      left: Float,
      top: Float,
      right: Float,
      bottom: Float,
      paint: Paint,
    ) {
      rects.add(RectF(left, top, right, bottom) to paint.color)
      super.drawRect(left, top, right, bottom, paint)
    }
  }

  private fun styleWithOverlayColor(): StyleConfig =
    MarkdownRenderTestSupport.styleWithSpoiler(
      MarkdownRenderTestSupport.defaultStyle.spoilerStyle.copy(color = OVERLAY),
    )

  private fun laidOutTextView(
    rendered: SpannableString,
    style: StyleConfig,
  ): TextView {
    val textView = TextView(context)
    textView.setTextSize(TypedValue.COMPLEX_UNIT_PX, style.paragraphStyle.fontSize)
    textView.text = rendered
    textView.measure(
      View.MeasureSpec.makeMeasureSpec(WIDTH, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    textView.layout(0, 0, WIDTH, textView.measuredHeight)
    return textView
  }

  private class Harness(
    val textView: TextView,
    val drawer: SpoilerOverlayDrawer,
    val rendered: SpannableString,
  ) {
    val spans: Array<SpoilerSpan> get() = rendered.getSpans(0, rendered.length, SpoilerSpan::class.java)

    fun draw(): RecordingCanvas {
      val canvas = RecordingCanvas(Bitmap.createBitmap(WIDTH, maxOf(textView.height, 1), Bitmap.Config.ARGB_8888))
      drawer.draw(canvas)
      return canvas
    }
  }

  private fun harness(
    document: MarkdownASTNode,
    overlay: SpoilerOverlay = SpoilerOverlay.SOLID,
    style: StyleConfig = styleWithOverlayColor(),
  ): Harness {
    val rendered = render(document, style)
    val textView = laidOutTextView(rendered, style)
    val drawer =
      requireNotNull(SpoilerOverlayDrawer.setupIfNeeded(textView, rendered, null, overlay)) {
        "Expected a drawer for a document that carries a spoiler"
      }
    return Harness(textView, drawer, rendered)
  }

  // MARK: Segment geometry

  @Test
  fun aSingleLineSpoilerPaintsOneSegment() {
    val canvas = harness(document(paragraph(spoiler(text("secret"))))).draw()

    assertEquals(1, canvas.roundRects.size)
    assertEquals(OVERLAY, canvas.roundRects.single().second)
  }

  @Test
  fun aWrappedSpoilerPaintsOneSegmentPerLine() {
    val long = List(40) { "concealed" }.joinToString(" ")
    val test = harness(document(paragraph(spoiler(text(long)))))

    val layout = requireNotNull(test.textView.layout)
    val span = test.spans.single()
    val expectedLines =
      layout.getLineForOffset(test.rendered.getSpanEnd(span)) -
        layout.getLineForOffset(test.rendered.getSpanStart(span)) + 1
    assertTrue("Expected the spoiler to wrap", expectedLines > 1)

    assertEquals(expectedLines, test.draw().roundRects.size)
  }

  @Test
  fun eachSegmentSitsOnItsOwnLineBand() {
    val long = List(40) { "concealed" }.joinToString(" ")
    val test = harness(document(paragraph(spoiler(text(long)))))
    val canvas = test.draw()

    val tops = canvas.roundRects.map { it.first.top }
    assertEquals("Segments must not share a band", tops.size, tops.toSet().size)
    canvas.roundRects.forEach { (rect, _) ->
      assertTrue("Segment should have a positive area", rect.width() > 0f && rect.height() > 0f)
      assertTrue("Segment should stay inside the view", rect.right <= WIDTH.toFloat() + 1f)
    }
  }

  @Test
  fun twoSpoilersPaintTwoSegments() {
    val canvas =
      harness(
        document(paragraph(spoiler(text("one")), text(" plain "), spoiler(text("two")))),
      ).draw()

    assertEquals(2, canvas.roundRects.size)
  }

  @Test
  fun computeSegmentRectFollowsTheLayout() {
    val test = harness(document(paragraph(spoiler(text("secret")))))
    val layout = requireNotNull(test.textView.layout)
    val span = test.spans.single()
    val start = test.rendered.getSpanStart(span)
    val end = test.rendered.getSpanEnd(span)

    val rect =
      computeSegmentRect(
        layout = layout,
        line = 0,
        segmentStart = start,
        segmentEnd = end,
        fontMetrics = layout.paint.fontMetrics,
        paddingLeft = 0f,
        paddingTop = 0f,
      )

    assertNotNull(rect)
    assertEquals(layout.getPrimaryHorizontal(start), rect!!.left, 0.01f)
    assertEquals(layout.getPrimaryHorizontal(end) - layout.getPrimaryHorizontal(start), rect.width, 0.01f)
  }

  @Test
  fun aZeroWidthSegmentIsSkipped() {
    val test = harness(document(paragraph(spoiler(text("secret")))))
    val layout = requireNotNull(test.textView.layout)

    val rect =
      computeSegmentRect(
        layout = layout,
        line = 0,
        segmentStart = 0,
        segmentEnd = 0,
        fontMetrics = layout.paint.fontMetrics,
        paddingLeft = 0f,
        paddingTop = 0f,
      )

    assertNull(rect)
  }

  // MARK: Overlay modes

  @Test
  fun theParticleOverlayPaintsTheSurfaceColorRatherThanRoundedBlocks() {
    val style =
      MarkdownRenderTestSupport.styleWithSpoiler(
        SpoilerStyle(color = OVERLAY, backgroundColor = Color.MAGENTA),
      )
    val canvas =
      harness(document(paragraph(spoiler(text("secret")))), SpoilerOverlay.PARTICLES, style).draw()

    assertEquals("Particles never draw the solid block", 0, canvas.roundRects.size)
    assertTrue(
      "The styled background color should cover the concealed text",
      canvas.rects.any { it.second == Color.MAGENTA },
    )
  }

  @Test
  fun switchingModesRepaintsWithTheOtherStrategy() {
    val test = harness(document(paragraph(spoiler(text("secret")))), SpoilerOverlay.PARTICLES)
    assertEquals(0, test.draw().roundRects.size)

    test.drawer.spoilerOverlay = SpoilerOverlay.SOLID

    assertEquals(1, test.draw().roundRects.size)
  }

  // MARK: Reveal transitions

  @Test
  fun revealingASpanThatWasNeverDrawnCompletesImmediately() {
    val test = harness(document(paragraph(spoiler(text("secret")))))
    val span = test.spans.single()
    var completed = false

    test.drawer.revealSpan(span) { completed = true }

    assertTrue(completed)
    assertTrue(span.revealed)
    assertFalse(span.revealing)
  }

  @Test
  fun aRevealInFlightMarksTheSpanRevealingButNotYetRevealed() {
    val test = harness(document(paragraph(spoiler(text("secret")))))
    test.draw()
    val span = test.spans.single()
    var completed = false

    test.drawer.revealSpan(span) { completed = true }

    assertTrue(span.revealing)
    assertFalse(span.revealed)
    assertFalse(completed)
  }

  @Test
  fun aRevealCompletesOnceItsDurationHasElapsed() {
    val test = harness(document(paragraph(spoiler(text("secret")))))
    test.draw()
    val span = test.spans.single()
    var completed = false

    test.drawer.revealSpan(span) { completed = true }
    // The first frame of the reveal stamps its start time; the second lands past the end of it.
    test.draw()
    ShadowSystemClock.advanceBy(Duration.ofMillis(1_000))
    test.draw()

    assertTrue("Reveal should have completed", completed)
    assertTrue(span.revealed)
    assertFalse(span.revealing)
  }

  @Test
  fun aRevealedSpanIsNoLongerPainted() {
    val test = harness(document(paragraph(spoiler(text("one")), text(" "), spoiler(text("two")))))
    test.draw()
    assertEquals(2, test.draw().roundRects.size)

    test.drawer.revealSpan(test.spans.first()) {}
    test.draw()
    ShadowSystemClock.advanceBy(Duration.ofMillis(1_000))
    test.draw()

    assertEquals("Only the still-concealed spoiler should be painted", 1, test.draw().roundRects.size)
  }

  @Test
  fun aDocumentWithoutSpoilersGetsNoDrawer() {
    val style = styleWithOverlayColor()
    val rendered = render(document(paragraph(text("nothing hidden"))), style)
    val textView = laidOutTextView(rendered, style)

    assertNull(SpoilerOverlayDrawer.setupIfNeeded(textView, rendered, null, SpoilerOverlay.SOLID))
  }
}
