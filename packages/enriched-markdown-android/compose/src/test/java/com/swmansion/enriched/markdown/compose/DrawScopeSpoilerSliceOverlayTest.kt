package com.swmansion.enriched.markdown.compose

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.text.Spannable
import android.util.TypedValue
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.LayoutDirection
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.EnrichedMarkdownInternalText
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.spans.SpoilerSpan
import com.swmansion.enriched.markdown.spoiler.CustomSpoilerOverlay
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlay
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlayHost
import com.swmansion.enriched.markdown.spoiler.SpoilerSlice
import com.swmansion.enriched.markdown.styles.SpoilerStyle
import com.swmansion.enriched.markdown.styles.StyleConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.shadows.ShadowSystemClock
import java.time.Duration
import kotlin.math.ceil
import kotlin.math.floor
import android.graphics.Color as AndroidColor

@RunWith(AndroidJUnit4::class)
// xhdpi, so the density the scope gets is not the default of 1.
@Config(sdk = [28], qualifiers = "xhdpi")
// The native runtime lays text out for real, which slice geometry and glyph pixels need.
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class DrawScopeSpoilerSliceOverlayTest {
  private val context: Context = ApplicationProvider.getApplicationContext()

  private companion object {
    const val WIDTH = 600
    val FILL = Color.Red
  }

  private class Probe {
    val created = mutableListOf<ProbeSlice>()
  }

  private enum class Drawing { FILL, TEXT, NOTHING }

  private data class ProbeOverlay(
    val probe: Probe,
    val drawing: Drawing = Drawing.FILL,
    val customReveal: Boolean = false,
  ) : CustomSpoilerOverlay {
    override fun createSliceOverlay(
      host: SpoilerOverlayHost,
      style: SpoilerStyle,
    ) = ProbeSlice(host, drawing, customReveal).also { probe.created.add(it) }
  }

  private class ProbeSlice(
    host: SpoilerOverlayHost,
    private val drawing: Drawing,
    private val customReveal: Boolean,
  ) : DrawScopeSpoilerSliceOverlay(host) {
    var slice: SpoilerSlice? = null
    var size: Size? = null
    var density = 0f
    var fontScale = 0f
    var layoutDirection: LayoutDirection? = null
    val revealProgress = mutableListOf<Float>()
    val revealSizes = mutableListOf<Size>()

    override fun DrawScope.draw(slice: SpoilerSlice) {
      this@ProbeSlice.slice = slice
      this@ProbeSlice.size = size
      this@ProbeSlice.density = density
      this@ProbeSlice.fontScale = fontScale
      this@ProbeSlice.layoutDirection = layoutDirection
      when (drawing) {
        Drawing.FILL -> drawRect(FILL)
        Drawing.TEXT -> drawSliceText(slice)
        Drawing.NOTHING -> Unit
      }
    }

    override fun DrawScope.drawReveal(
      slice: SpoilerSlice,
      progress: Float,
    ) {
      revealProgress.add(progress)
      revealSizes.add(size)
      if (customReveal) {
        drawRect(Color.Blue, size = size.copy(width = size.width * progress))
      } else {
        drawFadingOut(slice, progress)
      }
    }
  }

  private class Harness(
    val view: EnrichedMarkdownInternalText,
  ) {
    val span: SpoilerSpan
      get() = (view.text as Spannable).getSpans(0, view.text.length, SpoilerSpan::class.java).single()

    fun draw(): Bitmap {
      val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
      view.draw(Canvas(bitmap))
      return bitmap
    }

    /** Where the view draws [slice], in left-to-right text: left, top, right, bottom. */
    fun boundsOf(slice: SpoilerSlice): FloatArray {
      val layout = requireNotNull(view.layout)
      val layoutLine = layout.getLineForOffset(slice.start)
      val left = view.totalPaddingLeft + layout.getPrimaryHorizontal(slice.start)
      val top = view.totalPaddingTop + layout.getLineBaseline(layoutLine) - slice.baseline
      return floatArrayOf(left, top, left + slice.width, top + slice.height)
    }

    fun tapSpoiler() {
      val text = view.text as Spannable
      val layout = requireNotNull(view.layout)
      val x =
        view.totalPaddingLeft +
          (layout.getPrimaryHorizontal(text.getSpanStart(span)) + layout.getPrimaryHorizontal(text.getSpanEnd(span))) / 2f
      val y = view.totalPaddingTop + layout.getLineBaseline(0) - 2f
      for (action in listOf(MotionEvent.ACTION_DOWN, MotionEvent.ACTION_UP)) {
        val event = MotionEvent.obtain(0L, 0L, action, x, y, 0)
        view.movementMethod.onTouchEvent(view, text, event)
        event.recycle()
      }
    }

    fun advanceBy(millis: Long) = ShadowSystemClock.advanceBy(Duration.ofMillis(millis))
  }

  private fun harness(
    overlay: SpoilerOverlay,
    before: String = "plain ",
    secret: String = "secret words",
    after: String = " more",
  ): Harness {
    val style = StyleConfig.default(context)
    val paragraph =
      listOf(
        MarkdownASTNode(NodeType.Text, content = before),
        MarkdownASTNode(NodeType.Spoiler, children = listOf(MarkdownASTNode(NodeType.Text, content = secret))),
        MarkdownASTNode(NodeType.Text, content = after),
      ).filter { it.type != NodeType.Text || it.content.isNotEmpty() }
    val document =
      MarkdownASTNode(NodeType.Document, children = listOf(MarkdownASTNode(NodeType.Paragraph, children = paragraph)))
    val text = Renderer().apply { configure(style, context) }.renderDocument(document)

    val view = EnrichedMarkdownInternalText(context)
    view.layoutParams = ViewGroup.LayoutParams(WIDTH, ViewGroup.LayoutParams.WRAP_CONTENT)
    view.setTextSize(TypedValue.COMPLEX_UNIT_PX, style.paragraphStyle.fontSize)
    view.spoilerOverlay = overlay
    view.applyStyledText(text)
    view.measure(
      View.MeasureSpec.makeMeasureSpec(WIDTH, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    view.layout(0, 0, WIDTH, view.measuredHeight)
    return Harness(view)
  }

  /** Every pixel strictly inside [bounds], leaving out the edges where the clip antialiases. */
  private inline fun forEachPixelInside(
    bounds: FloatArray,
    action: (x: Int, y: Int) -> Unit,
  ) {
    for (x in ceil(bounds[0]).toInt() + 1 until floor(bounds[2]).toInt() - 1) {
      for (y in ceil(bounds[1]).toInt() + 1 until floor(bounds[3]).toInt() - 1) action(x, y)
    }
  }

  // MARK: The scope

  @Test
  fun theScopeCoversTheSliceAtTheHostsDensity() {
    val probe = Probe()
    val test = harness(ProbeOverlay(probe))

    val bitmap = test.draw()

    val slice = probe.created.single()
    val drawn = requireNotNull(slice.slice)
    assertEquals(Size(drawn.width, drawn.height), slice.size)
    assertEquals(2f, slice.density, 0f)
    assertEquals(test.view.resources.displayMetrics.density, slice.density, 0f)
    assertEquals(1f, slice.fontScale, 0f)
    assertEquals(LayoutDirection.Ltr, slice.layoutDirection)

    // Filled a few pixels in from each edge, and not a few pixels out.
    val (left, top, right, bottom) = test.boundsOf(drawn).map { it.toInt() }
    val midX = (left + right) / 2
    val midY = (top + bottom) / 2
    val inside = listOf(left + 2 to midY, right - 2 to midY, midX to top + 2, midX to bottom - 2, midX to midY)
    val outside = listOf(left - 2 to midY, right + 2 to midY, midX to top - 2, midX to bottom + 2)
    for ((x, y) in inside) assertEquals("Pixel ($x, $y)", FILL.toArgb(), bitmap.getPixel(x, y))
    for ((x, y) in outside) {
      if (x !in 0 until bitmap.width || y !in 0 until bitmap.height) continue
      assertTrue("Fill outside the slice at ($x, $y)", bitmap.getPixel(x, y) != FILL.toArgb())
    }
  }

  @Test
  fun theScopeFollowsTheUsersFontScale() {
    RuntimeEnvironment.setFontScale(1.5f)
    val probe = Probe()
    val test = harness(ProbeOverlay(probe))

    test.draw()
    val slice = probe.created.single()
    assertEquals(1.5f, slice.fontScale, 0f)

    // A change while the slice lives reaches its next draw.
    RuntimeEnvironment.setFontScale(2f)
    test.draw()
    assertTrue("The slice should outlive the change", probe.created.single() === slice)
    assertEquals(2f, slice.fontScale, 0f)
  }

  @Test
  fun theScopeFollowsTheDisplaysDensity() {
    val probe = Probe()
    val test = harness(ProbeOverlay(probe))

    test.draw()
    val slice = probe.created.single()
    assertEquals(2f, slice.density, 0f)

    // A change while the slice lives reaches its next draw.
    RuntimeEnvironment.setQualifiers("xxhdpi")
    test.draw()
    assertTrue("The slice should outlive the change", probe.created.single() === slice)
    assertEquals(3f, slice.density, 0f)
  }

  @Test
  fun anRtlParagraphGetsAnRtlScope() {
    val probe = Probe()
    val test = harness(ProbeOverlay(probe), before = "שלום ", secret = "סוד", after = "")

    test.draw()

    assertEquals(LayoutDirection.Rtl, probe.created.single().layoutDirection)
  }

  // MARK: Reveal

  @Test
  fun theDefaultRevealFadesTheDrawingOut() {
    val probe = Probe()
    val test = harness(ProbeOverlay(probe))
    test.draw()

    test.tapSpoiler()
    test.advanceBy(225)
    val bitmap = test.draw()

    val slice = probe.created.single()
    assertEquals(0.5f, slice.revealProgress.single(), 0.01f)
    // Halfway, the overlay is at a quarter of its opacity, as the text under it is at three
    // quarters. Pixels with a glyph under them are mixed, so only the bare fill is read.
    var bare = 0
    forEachPixelInside(test.boundsOf(requireNotNull(slice.slice))) { x, y ->
      val pixel = bitmap.getPixel(x, y)
      if (AndroidColor.green(pixel) != 0 || AndroidColor.blue(pixel) != 0) return@forEachPixelInside
      assertEquals("Alpha at ($x, $y)", 64f, AndroidColor.alpha(pixel).toFloat(), 2f)
      bare++
    }
    assertTrue("The slice should have bare fill", bare > 0)
  }

  @Test
  fun aCustomRevealReceivesTheProgressInTheSlicesScope() {
    val probe = Probe()
    val test = harness(ProbeOverlay(probe, customReveal = true))
    test.draw()

    test.tapSpoiler()
    test.advanceBy(90)
    test.draw()
    test.advanceBy(135)
    val bitmap = test.draw()

    val slice = probe.created.single()
    val drawn = requireNotNull(slice.slice)
    // A frame is a millisecond or so either way of where the clock was moved to.
    assertEquals(2, slice.revealProgress.size)
    assertEquals(0.2f, slice.revealProgress[0], 0.01f)
    assertEquals(0.5f, slice.revealProgress[1], 0.01f)
    assertEquals(Size(drawn.width, drawn.height), slice.revealSizes.last())

    // The override drew instead of the fade: a blue bar over the first half of the slice.
    val bounds = test.boundsOf(drawn)
    val y = ((bounds[1] + bounds[3]) / 2f).toInt()
    assertEquals(Color.Blue.toArgb(), bitmap.getPixel(ceil(bounds[0]).toInt() + 2, y))
    assertEquals(0, AndroidColor.blue(bitmap.getPixel(floor(bounds[2]).toInt() - 2, y)))
  }

  // MARK: Drawing the text through

  @Test
  fun drawSliceTextShowsTheConcealedGlyphs() {
    val bareProbe = Probe()
    val bare = harness(ProbeOverlay(bareProbe, Drawing.NOTHING))
    val textProbe = Probe()
    val throughOverlay = harness(ProbeOverlay(textProbe, Drawing.TEXT))

    val bareBitmap = bare.draw()
    val textBitmap = throughOverlay.draw()

    fun inkIn(
      test: Harness,
      bitmap: Bitmap,
      probe: Probe,
    ): Int {
      var inked = 0
      forEachPixelInside(test.boundsOf(requireNotNull(probe.created.single().slice))) { x, y ->
        if (AndroidColor.alpha(bitmap.getPixel(x, y)) > 0) inked++
      }
      return inked
    }
    assertEquals("A concealed spoiler draws no glyphs of its own", 0, inkIn(bare, bareBitmap, bareProbe))
    assertTrue("drawSliceText should put the glyphs in the slice", inkIn(throughOverlay, textBitmap, textProbe) > 0)
    assertFalse("Drawing them leaves the spoiler concealed", throughOverlay.span.revealed || throughOverlay.span.revealing)
  }

  // MARK: The README example

  @Test
  fun theReadmeShimmerCoversTheSpoilerAndWipesInReadingOrder() {
    val test = harness(ShimmerSpoiler())
    val text = test.view.text as Spannable
    val layout = requireNotNull(test.view.layout)
    val left = test.view.totalPaddingLeft + layout.getPrimaryHorizontal(text.getSpanStart(test.span))
    val right = test.view.totalPaddingLeft + layout.getPrimaryHorizontal(text.getSpanEnd(test.span))
    val quarter = (left + (right - left) / 4f).toInt()
    val threeQuarters = (left + (right - left) * 3f / 4f).toInt()
    // Just under the baseline, where "secret words" has no glyphs, so only the overlay shows.
    val y = test.view.totalPaddingTop + layout.getLineBaseline(0) + 3

    val concealed = test.draw()
    test.tapSpoiler()
    test.advanceBy(225)
    val halfway = test.draw()

    assertEquals(255, AndroidColor.alpha(concealed.getPixel(quarter, y)))
    assertEquals(255, AndroidColor.alpha(concealed.getPixel(threeQuarters, y)))
    assertEquals("The start is wiped away first", 0, AndroidColor.alpha(halfway.getPixel(quarter, y)))
    assertEquals("The end is still covered", 255, AndroidColor.alpha(halfway.getPixel(threeQuarters, y)))
  }
}
