package com.swmansion.enriched.markdown

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.text.Spannable
import android.text.TextPaint
import android.util.TypedValue
import android.view.View
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.spans.SpoilerSpan
import com.swmansion.enriched.markdown.spoiler.CustomSpoilerOverlay
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlay
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlayDrawer
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlayHost
import com.swmansion.enriched.markdown.spoiler.SpoilerSlice
import com.swmansion.enriched.markdown.spoiler.SpoilerSliceOverlay
import com.swmansion.enriched.markdown.styles.SpoilerStyle
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.image
import com.swmansion.enriched.markdown.test.TestAstFactory.lineBreak
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.spoiler
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.utils.text.ImageCache
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.shadows.ShadowSystemClock
import java.time.Duration
import kotlin.math.ceil
import kotlin.math.floor

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
// The native runtime lays text out for real, which slice geometry and glyph pixels need.
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SpoilerCustomOverlayTest {
  private val context: Context = ApplicationProvider.getApplicationContext()

  private companion object {
    const val WIDTH = 400
    const val OVERLAY = 0xFF884422.toInt()
    val LONG_SPOILER = List(40) { "concealed" }.joinToString(" ")
  }

  private class Probe {
    val created = mutableListOf<ProbeSlice>()
  }

  private data class ProbeOverlay(
    val tag: String,
    val probe: Probe,
    val drawsText: Boolean = false,
  ) : CustomSpoilerOverlay {
    override fun createSliceOverlay(
      host: SpoilerOverlayHost,
      style: SpoilerStyle,
    ): SpoilerSliceOverlay = ProbeSlice(style, drawsText).also { probe.created.add(it) }
  }

  private data class TimedProbeOverlay(
    val probe: Probe,
    override val revealDurationMillis: Long,
  ) : CustomSpoilerOverlay {
    override fun createSliceOverlay(
      host: SpoilerOverlayHost,
      style: SpoilerStyle,
    ): SpoilerSliceOverlay = ProbeSlice(style, drawsText = false).also { probe.created.add(it) }
  }

  private class ProbeSlice(
    val style: SpoilerStyle,
    private val drawsText: Boolean,
  ) : SpoilerSliceOverlay() {
    var slice: SpoilerSlice? = null
    var draws = 0
    val revealProgress = mutableListOf<Float>()
    var removals = 0

    override fun draw(
      canvas: Canvas,
      slice: SpoilerSlice,
    ) {
      this.slice = slice
      draws++
      if (drawsText) slice.drawText(canvas)
    }

    override fun drawReveal(
      canvas: Canvas,
      slice: SpoilerSlice,
      progress: Float,
    ) {
      revealProgress.add(progress)
      super.drawReveal(canvas, slice, progress)
    }

    override fun onRemoved() {
      removals++
    }
  }

  private class Harness(
    val textView: TextView,
    val drawer: SpoilerOverlayDrawer,
    val rendered: Spannable,
  ) {
    val span: SpoilerSpan get() = rendered.getSpans(0, rendered.length, SpoilerSpan::class.java).single()

    fun draw(): Bitmap {
      val bitmap = Bitmap.createBitmap(textView.width, textView.height, Bitmap.Config.ARGB_8888)
      drawer.draw(Canvas(bitmap))
      return bitmap
    }

    fun advanceBy(millis: Long) = ShadowSystemClock.advanceBy(Duration.ofMillis(millis))
  }

  private fun harness(
    document: MarkdownASTNode,
    overlay: SpoilerOverlay,
    style: StyleConfig =
      MarkdownRenderTestSupport.styleWithSpoiler(
        MarkdownRenderTestSupport.defaultStyle.spoilerStyle.copy(color = OVERLAY),
      ),
  ): Harness {
    val rendered = render(document, style)
    val textView = TextView(context)
    textView.setTextSize(TypedValue.COMPLEX_UNIT_PX, style.paragraphStyle.fontSize)
    textView.text = rendered
    textView.measure(
      View.MeasureSpec.makeMeasureSpec(WIDTH, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    textView.layout(0, 0, WIDTH, textView.measuredHeight)
    val drawer = requireNotNull(SpoilerOverlayDrawer.setupIfNeeded(textView, rendered, null, overlay))
    return Harness(textView, drawer, rendered)
  }

  private fun Harness.expectedLineCount(): Int {
    val layout = requireNotNull(textView.layout)
    return layout.getLineForOffset(rendered.getSpanEnd(span)) - layout.getLineForOffset(rendered.getSpanStart(span)) + 1
  }

  // MARK: Creation

  @Test
  fun aCustomOverlayGetsOneOverlayPerLineWithTheResolvedStyle() {
    val probe = Probe()
    val test = harness(document(paragraph(spoiler(text(LONG_SPOILER)))), ProbeOverlay("a", probe))
    assertTrue("Expected the spoiler to wrap", test.expectedLineCount() > 1)

    test.draw()

    assertEquals(test.expectedLineCount(), probe.created.size)
    probe.created.forEach { slice ->
      assertEquals(OVERLAY, slice.style.color)
      assertEquals(1, slice.draws)
    }
  }

  @Test
  fun sliceOverlaysLiveAcrossFrames() {
    val probe = Probe()
    val test = harness(document(paragraph(spoiler(text("secret")))), ProbeOverlay("a", probe))

    repeat(3) { test.draw() }

    assertEquals(1, probe.created.size)
    assertEquals(3, probe.created.single().draws)
  }

  @Test
  fun equalOverlaysKeepTheirSlicesWhileUnequalOnesRebuildThem() {
    val probe = Probe()
    val test = harness(document(paragraph(spoiler(text("secret")))), ProbeOverlay("a", probe))
    test.draw()
    val first = probe.created.single()

    test.drawer.spoilerOverlay = ProbeOverlay("a", probe)
    test.draw()

    assertEquals("An equal overlay keeps its slices", listOf(first), probe.created)
    assertEquals(0, first.removals)

    test.drawer.spoilerOverlay = ProbeOverlay("b", probe)

    assertEquals("A different overlay removes the old slices at once", 1, first.removals)
    test.draw()
    assertEquals(2, probe.created.size)
  }

  @Test
  fun aNewStyleRebuildsTheSlices() {
    val probe = Probe()
    val test = harness(document(paragraph(spoiler(text("secret")))), ProbeOverlay("a", probe))
    test.draw()

    val restyled = MarkdownRenderTestSupport.styleWithSpoiler(SpoilerStyle(color = Color.RED))
    test.drawer.registerSpans(render(document(paragraph(spoiler(text("secret")))), restyled).spoilerSpans())
    test.draw()

    assertEquals(1, probe.created.first().removals)
    assertEquals(
      Color.RED,
      probe.created
        .last()
        .style.color,
    )
  }

  @Test
  fun anImageLoadingUnderTheSpoilerRecreatesItsSlices() {
    val url = "test://spoiler-late-image"
    ImageCache.putOriginal(url, Bitmap.createBitmap(32, 32, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.RED) })
    val probe = Probe()
    // After a line break the image is a block one, which is drawn at its final width only once it
    // is registered with its view, the same path a download completing takes.
    val test = harness(document(paragraph(spoiler(text("secret"), lineBreak(), image(url)))), ProbeOverlay("a", probe))
    test.draw()
    val first = probe.created.toList()
    assertTrue(first.isNotEmpty())

    test.rendered
      .getSpans(0, test.rendered.length, ImageSpan::class.java)
      .single()
      .registerTextView(test.textView)
    test.draw()

    // The text's overlay is replaced in place; the image's line may now get an overlay of its own.
    val textSlice = requireNotNull(first.single().slice)
    assertEquals(1, first.single().removals)
    val replacement = probe.created.drop(1).map { requireNotNull(it.slice) }
    assertTrue(replacement.any { it.start == textSlice.start && it.end == textSlice.end })
    val created = probe.created.size
    test.draw()
    assertEquals("The new slices live on", created, probe.created.size)
  }

  @Test
  fun aRevealInFlightKeepsItsSlicesWhenTheContentChanges() {
    val probe = Probe()
    val test = harness(document(paragraph(spoiler(text("secret")))), ProbeOverlay("a", probe))
    test.draw()
    test.drawer.revealSpan(test.span) {}

    test.span.contentVersion++
    test.advanceBy(100)
    test.draw()

    val slice = probe.created.single()
    assertEquals(0, slice.removals)
    assertEquals(1, slice.revealProgress.size)
  }

  // MARK: Slice data

  @Test
  fun aWrappedSpoilerGivesEachSliceItsPlaceAndRanges() {
    val probe = Probe()
    val test = harness(document(paragraph(text("before "), spoiler(text(LONG_SPOILER)))), ProbeOverlay("a", probe))
    test.draw()

    val spanStart = test.rendered.getSpanStart(test.span)
    val spanEnd = test.rendered.getSpanEnd(test.span)
    val slices = probe.created.map { requireNotNull(it.slice) }.sortedBy { it.index }
    val count = test.expectedLineCount()

    assertEquals((0 until count).toList(), slices.map { it.index })
    slices.forEach { slice ->
      assertEquals(count, slice.count)
      assertEquals(spanStart, slice.spoilerStart)
      assertEquals(spanEnd, slice.spoilerEnd)
      assertEquals(test.rendered.substring(slice.start, slice.end), slice.text.toString())
      assertTrue(slice.width > 0f && slice.height > 0f)
    }
    assertEquals("The first slice starts the spoiler", spanStart, slices.first().start)
    assertEquals("The last slice ends it", spanEnd, slices.last().end)
    slices.zipWithNext().forEach { (line, next) ->
      assertEquals("Slices are contiguous, in reading order", line.end, next.start)
    }
  }

  @Test
  fun theSlicesTextIsStyledAsRevealed() {
    val probe = Probe()
    val test = harness(document(paragraph(spoiler(text("secret")))), ProbeOverlay("a", probe))
    test.draw()

    val text = requireNotNull(probe.created.single().slice).text as Spannable

    assertEquals(0, text.getSpans(0, text.length, SpoilerSpan::class.java).size)
  }

  @Test
  fun theBaselineIsMeasuredFromTheSlicesTop() {
    val probe = Probe()
    val test = harness(document(paragraph(spoiler(text("secret")))), ProbeOverlay("a", probe))
    test.draw()

    val slice = requireNotNull(probe.created.single().slice)
    val metrics = TextPaint().apply { textSize = test.span.blockStyle.fontSize }.fontMetrics

    // The slice spans the block font's ascent to descent around the line's baseline.
    assertEquals(-metrics.ascent, slice.baseline, 1f)
    assertEquals(metrics.descent - metrics.ascent, slice.height, 1f)
  }

  @Test
  fun theSliceKnowsWhichWayItsParagraphRuns() {
    val ltr = Probe()
    val rtl = Probe()
    harness(document(paragraph(text("plain "), spoiler(text("secret")))), ProbeOverlay("a", ltr)).draw()
    harness(document(paragraph(text("שלום "), spoiler(text("סוד")))), ProbeOverlay("a", rtl)).draw()

    assertFalse(requireNotNull(ltr.created.single().slice).isRtl)
    assertTrue(requireNotNull(rtl.created.single().slice).isRtl)
  }

  // MARK: Reveal

  @Test
  fun revealProgressReachesDrawRevealInStepWithTheText() {
    val probe = Probe()
    val test = harness(document(paragraph(spoiler(text("secret")))), ProbeOverlay("a", probe))
    test.draw()

    test.drawer.revealSpan(test.span) {}
    test.advanceBy(225)
    test.draw()

    val slice = probe.created.single()
    assertEquals(0.5f, slice.revealProgress.single(), 0.001f)
    // Halfway through, the overlay is at a quarter of its opacity and the text at the rest.
    assertEquals(0.75f, test.span.textAlpha, 0.001f)
  }

  @Test
  fun anOverlaysRevealDurationSetsTheClock() {
    val probe = Probe()
    val test = harness(document(paragraph(spoiler(text("secret")))), TimedProbeOverlay(probe, 1_000))
    test.draw()
    var completed = false

    test.drawer.revealSpan(test.span) { completed = true }
    test.advanceBy(250)
    test.draw()

    val slice = probe.created.single()
    assertEquals(0.25f, slice.revealProgress.single(), 0.001f)
    assertEquals(1f - 0.75f * 0.75f, test.span.textAlpha, 0.001f)

    test.advanceBy(450)
    test.draw()
    assertFalse("Past the default duration, a longer reveal is still running", completed)

    test.advanceBy(300)
    test.draw()
    assertTrue(completed)
    assertTrue(test.span.revealed)
  }

  @Test
  fun aZeroRevealDurationRevealsAtOnce() {
    val probe = Probe()
    val test = harness(document(paragraph(spoiler(text("secret")))), TimedProbeOverlay(probe, 0))
    test.draw()
    var completed = false

    test.drawer.revealSpan(test.span) { completed = true }
    test.draw()

    val slice = probe.created.single()
    assertTrue(completed)
    assertTrue(test.span.revealed)
    assertEquals(1, slice.removals)
    assertTrue("No reveal frame is drawn", slice.revealProgress.isEmpty())
  }

  @Test
  fun aFinishedRevealRemovesTheSliceAndRevealsTheSpan() {
    val probe = Probe()
    val test = harness(document(paragraph(spoiler(text("secret")))), ProbeOverlay("a", probe))
    test.draw()
    var completed = false

    test.drawer.revealSpan(test.span) { completed = true }
    test.advanceBy(100)
    test.draw()
    test.advanceBy(1_000)
    test.draw()

    val slice = probe.created.single()
    assertTrue(completed)
    assertTrue(test.span.revealed)
    assertFalse(test.span.revealing)
    assertEquals(1, slice.removals)
    assertEquals("The slice is removed before a frame past the end", 1, slice.revealProgress.size)
    test.draw()
    assertEquals("A revealed spoiler gets no new slices", 1, probe.created.size)
  }

  @Test
  fun switchingOverlaysMidRevealCompletesTheSpan() {
    val probe = Probe()
    val test = harness(document(paragraph(spoiler(text("secret")))), ProbeOverlay("a", probe))
    test.draw()
    var completed = false
    test.drawer.revealSpan(test.span) { completed = true }

    test.drawer.spoilerOverlay = SpoilerOverlay.Solid()

    assertTrue(completed)
    assertTrue(test.span.revealed)
    assertEquals(1, probe.created.single().removals)
  }

  @Test
  fun aSliceThatAppearsMidRevealIsNotCreated() {
    val probe = Probe()
    val prefix = List(30) { "plain" }.joinToString(" ", postfix = " ")
    val test = harness(document(paragraph(text(prefix), spoiler(text(LONG_SPOILER)))), ProbeOverlay("a", probe))
    test.draw()
    val before = probe.created.size
    test.drawer.revealSpan(test.span) {}

    test.textView.measure(
      View.MeasureSpec.makeMeasureSpec(WIDTH / 2, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    test.textView.layout(0, 0, WIDTH / 2, test.textView.measuredHeight)
    test.draw()

    assertEquals(before, probe.created.size)
    assertTrue("Losing its slices finishes the reveal", test.span.revealed)
  }

  // MARK: Drawing the text through

  @Test
  fun drawTextPutsTheGlyphsWhereTheTextViewDrawsThem() {
    val probe = Probe()
    val test =
      harness(
        document(paragraph(text("plain "), spoiler(text("secret words")), text(" more"))),
        ProbeOverlay("a", probe, drawsText = true),
      )
    test.textView.paint.color = Color.BLACK
    val throughOverlay = test.draw()
    val slice = requireNotNull(probe.created.single().slice)

    test.span.markRevealed()
    val revealed = Bitmap.createBitmap(test.textView.width, test.textView.height, Bitmap.Config.ARGB_8888)
    Canvas(revealed).apply {
      translate(test.textView.totalPaddingLeft.toFloat(), test.textView.totalPaddingTop.toFloat())
      requireNotNull(test.textView.layout).draw(this)
    }

    val layout = requireNotNull(test.textView.layout)
    val left = test.textView.totalPaddingLeft + layout.getPrimaryHorizontal(slice.start)
    val top = test.textView.totalPaddingTop + layout.getLineBaseline(0) - slice.baseline
    // Inside the slice, pixel for pixel; the edges are left out, where the clip antialiases.
    var inked = 0
    for (x in ceil(left).toInt() + 1 until floor(left + slice.width).toInt() - 1) {
      for (y in ceil(top).toInt() + 1 until floor(top + slice.height).toInt() - 1) {
        assertEquals("Pixel ($x, $y)", revealed.getPixel(x, y), throughOverlay.getPixel(x, y))
        if (Color.alpha(revealed.getPixel(x, y)) > 0) inked++
      }
    }
    assertTrue("The slice should hold glyphs", inked > 0)

    // Outside the slice, the neighbouring text is clipped away.
    for (x in 0 until floor(left).toInt()) {
      for (y in 0 until throughOverlay.height) {
        assertEquals(0, Color.alpha(throughOverlay.getPixel(x, y)))
      }
    }
  }

  @Test
  fun drawTextLeavesTheSpoilerConcealed() {
    val probe = Probe()
    val test = harness(document(paragraph(spoiler(text("secret")))), ProbeOverlay("a", probe, drawsText = true))

    test.draw()

    assertEquals(0f, test.span.textAlpha, 0f)
    assertFalse(test.span.revealed)
  }

  // MARK: The README example

  @Test
  fun theReadmePixelatedSpoilerDrawsTheTextAsHardEdgedBlocks() {
    val document = document(paragraph(text("plain "), spoiler(text("secret words")), text(" more")))
    // The same text through a probe, for the slice's geometry.
    val probe = Probe()
    val probed = harness(document, ProbeOverlay("a", probe))
    probed.draw()
    val slice = requireNotNull(probe.created.single().slice)
    val layout = requireNotNull(probed.textView.layout)
    val left = probed.textView.totalPaddingLeft + layout.getPrimaryHorizontal(slice.start)
    val top = probed.textView.totalPaddingTop + layout.getLineBaseline(0) - slice.baseline

    val test = harness(document, PixelatedSpoiler())
    test.textView.paint.color = Color.BLACK
    val bitmap = test.draw()

    val blockSize = 6f * test.textView.resources.displayMetrics.density
    val columns = (slice.width / blockSize).toInt()
    val rows = (slice.height / blockSize).toInt()
    val blockWidth = slice.width / columns
    val blockHeight = slice.height / rows
    var inked = 0
    for (column in 0 until columns) {
      for (row in 0 until rows) {
        // Two neighbouring pixels well inside one block: unfiltered, they match.
        val x = (left + (column + 0.5f) * blockWidth).toInt()
        val y = (top + (row + 0.5f) * blockHeight).toInt()
        assertEquals("Block ($column, $row)", bitmap.getPixel(x, y), bitmap.getPixel(x + 1, y + 1))
        if (Color.alpha(bitmap.getPixel(x, y)) > 0) inked++
      }
    }
    assertTrue("Some blocks should hold the text", inked > 0)
    assertFalse(test.span.revealed)
  }

  private fun Spannable.spoilerSpans(): Array<SpoilerSpan> = getSpans(0, length, SpoilerSpan::class.java)
}
