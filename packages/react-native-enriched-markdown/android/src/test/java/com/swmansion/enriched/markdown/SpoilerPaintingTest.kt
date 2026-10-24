package com.swmansion.enriched.markdown

import android.animation.ValueAnimator
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.provider.Settings
import android.text.Spannable
import android.text.TextPaint
import android.util.TypedValue
import android.view.View
import android.widget.TextView
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.spans.SpoilerSpan
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlay
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlayDrawer
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlayMode
import com.swmansion.enriched.markdown.spoiler.computeSliceRect
import com.swmansion.enriched.markdown.styles.SpoilerStyle
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.test.TestAstFactory.code
import com.swmansion.enriched.markdown.test.TestAstFactory.heading
import com.swmansion.enriched.markdown.test.TestAstFactory.highlight
import com.swmansion.enriched.markdown.test.TestAstFactory.image
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.spoiler
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.utils.text.ImageCache
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.shadows.ShadowSystemClock
import org.robolectric.util.ReflectionHelpers
import org.robolectric.util.ReflectionHelpers.ClassParameter
import java.time.Duration

/**
 * Covers how spoilers are concealed (the text drawn transparent, with the overlay painted over each
 * slice) and the state machine a reveal walks through. Ported from the enriched-markdown-android
 * library's SpoilerPaintingTest.
 *
 * Frames are drawn by hand with [ShadowSystemClock] as the clock, since Robolectric only advances
 * [android.view.Choreographer] through a paused looper.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
// Robolectric's legacy graphics report zero font metrics, which collapses every slice rect to
// zero height; the native runtime lays text out for real, which is what this geometry needs.
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SpoilerPaintingTest {
  private val context = RuntimeEnvironment.getApplication()

  private companion object {
    const val WIDTH = 400
    const val OVERLAY = 0xFF884422.toInt()
    const val HIGHLIGHT = 0xFFFFEE00.toInt()
  }

  /** Records the shapes drawn onto it, in view coordinates, with their colors. */
  private class RecordingCanvas(
    val bitmap: Bitmap,
  ) : Canvas(bitmap) {
    private val currentMatrix = Matrix()
    val roundRects = mutableListOf<Pair<RectF, Int>>()
    val rects = mutableListOf<Pair<RectF, Int>>()
    val pathColors = mutableListOf<Int>()

    override fun drawPath(
      path: Path,
      paint: Paint,
    ) {
      pathColors.add(paint.color)
      super.drawPath(path, paint)
    }

    override fun drawRoundRect(
      rect: RectF,
      rx: Float,
      ry: Float,
      paint: Paint,
    ) {
      roundRects.add(inViewCoordinates(RectF(rect)) to paint.color)
      super.drawRoundRect(rect, rx, ry, paint)
    }

    override fun drawRect(
      left: Float,
      top: Float,
      right: Float,
      bottom: Float,
      paint: Paint,
    ) {
      rects.add(inViewCoordinates(RectF(left, top, right, bottom)) to paint.color)
      super.drawRect(left, top, right, bottom, paint)
    }

    // Overlays draw in their slice's coordinates, under a translation. getMatrix is deprecated
    // because a hardware canvas's matrix is implementation-defined; over a bitmap it is exact.
    @Suppress("DEPRECATION")
    private fun inViewCoordinates(rect: RectF): RectF {
      getMatrix(currentMatrix)
      currentMatrix.mapRect(rect)
      return rect
    }
  }

  private fun testStyle(): StyleConfig =
    styleConfig(
      elements =
        mapOf(
          "spoiler" to mapOf("color" to OVERLAY),
          "code" to mapOf("backgroundColor" to Color.RED, "borderColor" to Color.RED),
          "highlight" to mapOf("backgroundColor" to HIGHLIGHT),
        ),
    )

  private fun laidOutTextView(
    rendered: Spannable,
    style: StyleConfig,
  ): TextView {
    val textView = TextView(context)
    textView.setTextSize(TypedValue.COMPLEX_UNIT_PX, style.paragraphStyle.fontSize)
    textView.text = rendered
    textView.layOutAt(WIDTH)
    return textView
  }

  private fun TextView.layOutAt(width: Int) {
    measure(
      View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    layout(0, 0, width, measuredHeight)
  }

  private class Harness(
    val textView: TextView,
    val drawer: SpoilerOverlayDrawer,
    val rendered: Spannable,
  ) {
    val spans: Array<SpoilerSpan> get() = rendered.getSpans(0, rendered.length, SpoilerSpan::class.java)

    fun draw(): RecordingCanvas {
      val canvas = RecordingCanvas(Bitmap.createBitmap(maxOf(textView.width, 1), maxOf(textView.height, 1), Bitmap.Config.ARGB_8888))
      drawer.draw(canvas)
      return canvas
    }

    /** Draws the text itself, with its line backgrounds, rather than the overlay. */
    fun drawText(): RecordingCanvas {
      val canvas = RecordingCanvas(Bitmap.createBitmap(maxOf(textView.width, 1), maxOf(textView.height, 1), Bitmap.Config.ARGB_8888))
      requireNotNull(textView.layout).draw(canvas)
      return canvas
    }
  }

  private fun harness(
    block: MarkdownASTNode,
    mode: SpoilerOverlayMode = SpoilerOverlayMode.SOLID,
    style: StyleConfig = testStyle(),
  ): Harness {
    val rendered = render(style, block)
    val textView = laidOutTextView(rendered, style)
    val drawer =
      requireNotNull(SpoilerOverlayDrawer.setupIfNeeded(textView, rendered, null, mode)) {
        "Expected a drawer for a document that carries a spoiler"
      }
    return Harness(textView, drawer, rendered)
  }

  // MARK: Style mapping

  @Test
  fun theOverlayPropPicksTheBuiltInOverlayTunedByTheSpoilerStyle() {
    val style = SpoilerStyle(color = OVERLAY, particleDensity = 12f, particleSpeed = 30f, solidBorderRadius = 6f)

    assertEquals(SpoilerOverlay.Particles(density = 12f, speed = 30f), SpoilerOverlayMode.PARTICLES.toOverlay(style))
    assertEquals(SpoilerOverlay.Solid(cornerRadius = 6f), SpoilerOverlayMode.SOLID.toOverlay(style))
    assertEquals(SpoilerOverlayMode.SOLID, SpoilerOverlayMode.fromString("solid"))
    assertEquals(SpoilerOverlayMode.PARTICLES, SpoilerOverlayMode.fromString("particles"))
    assertEquals(SpoilerOverlayMode.PARTICLES, SpoilerOverlayMode.fromString(null))
  }

  @Test
  fun theSpoilerStyleIsReadFromTheMarkdownStyle() {
    val style =
      styleConfig(
        elements =
          mapOf(
            "spoiler" to mapOf("color" to OVERLAY),
          ),
      ).spoilerStyle

    // The test style map's particles and solid entries.
    assertEquals(SpoilerStyle(color = OVERLAY, particleDensity = 0.5f, particleSpeed = 1f, solidBorderRadius = 0f), style)
  }

  // MARK: Concealment

  @Test
  fun aConcealedSpoilerDrawsItsTextTransparent() {
    val span = harness(paragraph(spoiler(text("secret")))).spans.single()
    val paint = TextPaint().apply { color = Color.BLACK }

    span.updateDrawState(paint)
    assertEquals(0, Color.alpha(paint.color))

    span.textAlpha = 0.5f
    paint.color = Color.BLACK
    span.updateDrawState(paint)
    assertEquals(127, Color.alpha(paint.color))

    span.markRevealed()
    paint.color = Color.BLACK
    span.updateDrawState(paint)
    assertEquals(Color.BLACK, paint.color)
  }

  @Test
  fun aConcealedSpoilerDrawsNoInkUntilRevealed() {
    val test = harness(paragraph(spoiler(text("secret"))))

    assertEquals(0, test.drawText().bitmap.inkedPixels())

    test.spans.single().markRevealed()
    assertTrue("The text should draw once revealed", test.drawText().bitmap.inkedPixels() > 0)
  }

  // MARK: Slice geometry

  @Test
  fun aSingleLineSpoilerPaintsOneOverlay() {
    val canvas = harness(paragraph(spoiler(text("secret")))).draw()

    assertEquals(1, canvas.roundRects.size)
    assertEquals(OVERLAY, canvas.roundRects.single().second)
  }

  @Test
  fun aWrappedSpoilerPaintsOneOverlayPerLine() {
    val long = List(40) { "concealed" }.joinToString(" ")
    val test = harness(paragraph(spoiler(text(long))))

    val layout = requireNotNull(test.textView.layout)
    val span = test.spans.single()
    val expectedLines =
      layout.getLineForOffset(test.rendered.getSpanEnd(span)) -
        layout.getLineForOffset(test.rendered.getSpanStart(span)) + 1
    assertTrue("Expected the spoiler to wrap", expectedLines > 1)

    assertEquals(expectedLines, test.draw().roundRects.size)
  }

  @Test
  fun twoSpoilersPaintTwoOverlays() {
    val canvas = harness(paragraph(spoiler(text("one")), text(" plain "), spoiler(text("two")))).draw()

    assertEquals(2, canvas.roundRects.size)
  }

  @Test
  fun computeSliceRectFollowsTheLayout() {
    val test = harness(paragraph(spoiler(text("secret"))))
    val layout = requireNotNull(test.textView.layout)
    val span = test.spans.single()
    val start = test.rendered.getSpanStart(span)
    val end = test.rendered.getSpanEnd(span)

    val rect = computeSliceRect(layout, 0, start, end, layout.paint.fontMetrics, 0f, 0f)

    assertNotNull(rect)
    assertEquals(layout.getPrimaryHorizontal(start), rect!!.left, 0.01f)
    assertEquals(layout.getPrimaryHorizontal(end) - layout.getPrimaryHorizontal(start), rect.width, 0.01f)
  }

  @Test
  fun aZeroWidthSliceIsSkipped() {
    val test = harness(paragraph(spoiler(text("secret"))))
    val layout = requireNotNull(test.textView.layout)

    assertNull(computeSliceRect(layout, 0, 0, 0, layout.paint.fontMetrics, 0f, 0f))
  }

  @Test
  fun aSliceCoversTheSpansOwnFontSize() {
    val test = harness(heading(1, spoiler(text("secret"))))
    val span = test.spans.single()
    assertTrue(
      "The heading must be larger than the view's base size for this to be meaningful",
      span.blockStyle.fontSize > test.textView.textSize,
    )
    val metrics = TextPaint().apply { textSize = span.blockStyle.fontSize }.fontMetrics

    val rect =
      test
        .draw()
        .roundRects
        .single()
        .first

    assertEquals(metrics.descent - metrics.ascent, rect.height(), 1f)
  }

  // MARK: Overlay modes

  @Test
  fun theParticleOverlayPaintsNoBackdrop() {
    val canvas = harness(paragraph(spoiler(text("secret"))), SpoilerOverlayMode.PARTICLES).draw()

    assertEquals("Particles never draw the solid block", 0, canvas.roundRects.size)
    assertEquals("The text is drawn transparent, so nothing covers it", 0, canvas.rects.size)
  }

  @Test
  fun switchingModesRepaintsWithTheOtherOverlay() {
    val test = harness(paragraph(spoiler(text("secret"))), SpoilerOverlayMode.PARTICLES)
    assertEquals(0, test.draw().roundRects.size)

    test.drawer.overlayMode = SpoilerOverlayMode.SOLID

    assertEquals(1, test.draw().roundRects.size)
  }

  // MARK: Decorations under a spoiler

  @Test
  fun inlineCodeUnderAConcealedSpoilerPaintsNoBackground() {
    val test = harness(paragraph(spoiler(text("see "), code("secret"))))

    assertTrue(
      "A concealed code background would outline the hidden text",
      test.drawText().pathColors.none { Color.alpha(it) > 0 },
    )
  }

  @Test
  fun inlineCodeBackgroundReturnsOnceTheSpoilerIsRevealed() {
    val test = harness(paragraph(spoiler(text("see "), code("secret"))))

    test.spans.single().markRevealed()

    assertTrue(test.drawText().pathColors.any { Color.alpha(it) > 0 })
  }

  @Test
  fun highlightUnderAConcealedSpoilerPaintsNoBand() {
    val test = harness(paragraph(spoiler(text("see "), highlight(text("secret")))))

    assertTrue(
      "A concealed highlight band would outline the hidden text",
      test.drawText().rects.none { Color.alpha(it.second) > 0 },
    )
  }

  @Test
  fun highlightBandReturnsOnceTheSpoilerIsRevealed() {
    val test = harness(paragraph(spoiler(text("see "), highlight(text("secret")))))

    test.spans.single().markRevealed()

    assertTrue(test.drawText().rects.any { it.second == HIGHLIGHT })
  }

  // A drawable ignores the paint, so an image has to be concealed explicitly.
  @Test
  fun anInlineImageUnderAConcealedSpoilerIsNotDrawn() {
    val url = "test://spoiler-inline-image"
    ImageCache.putOriginal(ImageCache.requestKey(url, emptyMap()), redBitmap())
    val test = harness(paragraph(text("see "), spoiler(image(url))))

    assertEquals(0, test.drawText().bitmap.redPixels())

    test.spans.single().textAlpha = 0.5f
    assertTrue("The image should fade in with the text", test.drawText().bitmap.redPixels() > 0)

    test.spans.single().markRevealed()
    assertTrue(test.drawText().bitmap.redPixels() > 0)
  }

  @Test
  fun aSliceOverABlockImageCoversTheWholeImage() {
    val url = "test://spoiler-block-image"
    ImageCache.putOriginal(ImageCache.requestKey(url, emptyMap()), redBitmap())
    val style = testStyle()
    val rendered = render(style, paragraph(spoiler(image(url))))
    // A block image takes its width from the view it is registered with, as the segment views do,
    // so the text is laid out again once it has one.
    rendered
      .getSpans(0, rendered.length, ImageSpan::class.java)
      .single()
      .registerTextView(laidOutTextView(rendered, style))
    val textView = laidOutTextView(rendered, style)
    val drawer = requireNotNull(SpoilerOverlayDrawer.setupIfNeeded(textView, rendered, null, SpoilerOverlayMode.SOLID))
    val test = Harness(textView, drawer, rendered)
    val imageHeight = style.imageStyle.height
    val textMetrics = test.textView.paint.fontMetrics
    assertTrue(
      "The image must be taller than a line of text for this to be meaningful",
      imageHeight > textMetrics.descent - textMetrics.ascent,
    )

    val rect =
      test
        .draw()
        .roundRects
        .single()
        .first

    val lineTop = requireNotNull(test.textView.layout).getLineTop(0) + test.textView.totalPaddingTop
    assertEquals(lineTop.toFloat(), rect.top, 1f)
    assertEquals(imageHeight, rect.height(), 1f)
    assertEquals("The image itself stays hidden under the overlay", 0, test.drawText().bitmap.redPixels())
  }

  private fun redBitmap(): Bitmap = Bitmap.createBitmap(32, 32, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.RED) }

  private fun Bitmap.inkedPixels(): Int = pixels().count { Color.alpha(it) > 0 }

  private fun Bitmap.redPixels(): Int = pixels().count { Color.alpha(it) > 0 && Color.red(it) > 128 && Color.green(it) < 64 }

  private fun Bitmap.pixels(): IntArray = IntArray(width * height).also { getPixels(it, 0, width, 0, 0, width, height) }

  // MARK: Reveal transitions

  @Test
  fun revealingASpanThatWasNeverDrawnCompletesImmediately() {
    val test = harness(paragraph(spoiler(text("secret"))))
    val span = test.spans.single()
    var completed = false

    test.drawer.revealSpan(span) { completed = true }

    assertTrue(completed)
    assertTrue(span.revealed)
    assertFalse(span.revealing)
  }

  @Test
  fun aRevealInFlightMarksTheSpanRevealingButNotYetRevealed() {
    val test = harness(paragraph(spoiler(text("secret"))))
    test.draw()
    val span = test.spans.single()
    var completed = false

    test.drawer.revealSpan(span) { completed = true }

    assertTrue(span.revealing)
    assertFalse(span.revealed)
    assertFalse(completed)
  }

  @Test
  fun aRevealFadesTheTextInAsTheOverlayFadesOut() {
    val test = harness(paragraph(spoiler(text("secret"))))
    test.draw()
    val span = test.spans.single()

    test.drawer.revealSpan(span) {}
    ShadowSystemClock.advanceBy(Duration.ofMillis(225))
    val halfway = test.draw()

    assertTrue("The text is partly visible halfway through", span.textAlpha > 0f && span.textAlpha < 1f)
    val overlayAlpha = Color.alpha(halfway.roundRects.single().second)
    assertTrue("The overlay is partly faded halfway through", overlayAlpha in 1..254)
  }

  @Test
  fun aRevealCompletesOnceItsDurationHasElapsed() {
    val test = harness(paragraph(spoiler(text("secret"))))
    test.draw()
    val span = test.spans.single()
    var completed = false

    test.drawer.revealSpan(span) { completed = true }
    test.draw()
    ShadowSystemClock.advanceBy(Duration.ofMillis(1_000))
    test.draw()

    assertTrue("Reveal should have completed", completed)
    assertTrue(span.revealed)
    assertFalse(span.revealing)
  }

  @Test
  fun aRevealCompletesAtOnceWithAnimationsTurnedOff() {
    val test = harness(paragraph(spoiler(text("secret"))))
    test.draw()
    val span = test.spans.single()
    var completed = false

    setAnimatorDurationScale(0f)
    try {
      test.drawer.revealSpan(span) { completed = true }
      test.draw()
    } finally {
      setAnimatorDurationScale(1f)
    }

    assertTrue("Reveal should complete without waiting out its duration", completed)
    assertTrue(span.revealed)
  }

  // Below API 33 the process scale can't be read back, so the setting is what the drawer follows.
  @Test
  fun aRevealStretchesWithTheAnimatorDurationScaleSetting() {
    val test = harness(paragraph(spoiler(text("secret"))))
    test.draw()
    val span = test.spans.single()
    var completed = false
    Settings.Global.putFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 2f)
    try {
      test.drawer.revealSpan(span) { completed = true }
      ShadowSystemClock.advanceBy(Duration.ofMillis(600))
      test.draw()
      assertFalse("At 2x, a reveal is still running past its own duration", completed)

      ShadowSystemClock.advanceBy(Duration.ofMillis(400))
      test.draw()
      assertTrue(completed)
    } finally {
      Settings.Global.putFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f)
    }
  }

  @Test
  @Config(sdk = [35])
  fun aRevealFollowsTheProcessAnimatorDurationScale() {
    val test = harness(paragraph(spoiler(text("secret"))))
    test.draw()
    val span = test.spans.single()
    var completed = false

    setAnimatorDurationScale(0.5f)
    try {
      test.drawer.revealSpan(span) { completed = true }
      ShadowSystemClock.advanceBy(Duration.ofMillis(250))
      test.draw()
    } finally {
      setAnimatorDurationScale(1f)
    }

    assertTrue("At 0.5x, a reveal ends in half its duration", completed)
  }

  // What the developer option "Animator duration scale" sets; the setter is hidden from the SDK.
  private fun setAnimatorDurationScale(scale: Float) {
    ReflectionHelpers.callStaticMethod<Unit>(
      ValueAnimator::class.java,
      "setDurationScale",
      ClassParameter.from(Float::class.javaPrimitiveType, scale),
    )
  }

  @Test
  fun aRevealedSpanIsNoLongerPainted() {
    val test = harness(paragraph(spoiler(text("one")), text(" "), spoiler(text("two"))))
    assertEquals(2, test.draw().roundRects.size)

    test.drawer.revealSpan(test.spans.first()) {}
    test.draw()
    ShadowSystemClock.advanceBy(Duration.ofMillis(1_000))
    test.draw()

    assertEquals("Only the still-concealed spoiler should be painted", 1, test.draw().roundRects.size)
  }

  @Test
  fun switchingModesMidRevealFinishesTheReveal() {
    val test = harness(paragraph(spoiler(text("secret"))))
    test.draw()
    val span = test.spans.single()
    var completed = false
    test.drawer.revealSpan(span) { completed = true }

    test.drawer.overlayMode = SpoilerOverlayMode.PARTICLES

    assertTrue(completed)
    assertTrue(span.revealed)
  }

  @Test
  fun stoppingMidRevealFinishesTheReveal() {
    val test = harness(paragraph(spoiler(text("secret"))), SpoilerOverlayMode.PARTICLES)
    test.draw()
    val span = test.spans.single()
    test.drawer.revealSpan(span) {}

    test.drawer.stop()

    assertTrue(span.revealed)
  }

  @Test
  fun aRestyleCarriesRevealsOver() {
    val block = paragraph(spoiler(text("one")), text(" "), spoiler(text("two")))
    val style = testStyle()
    val before = render(style, block)
    val after = render(style, block)
    before.getSpans(0, before.length, SpoilerSpan::class.java).minBy { before.getSpanStart(it) }.markRevealed()

    SpoilerOverlayDrawer.carryOverReveals(before, after)

    val revealed = after.getSpans(0, after.length, SpoilerSpan::class.java).sortedBy { after.getSpanStart(it) }.map { it.revealed }
    assertEquals(listOf(true, false), revealed)
  }

  @Test
  fun aDocumentWithoutSpoilersGetsNoDrawer() {
    val style = testStyle()
    val rendered = render(style, paragraph(text("nothing hidden")))
    val textView = laidOutTextView(rendered, style)

    assertNull(SpoilerOverlayDrawer.setupIfNeeded(textView, rendered, null, SpoilerOverlayMode.SOLID))
  }
}
