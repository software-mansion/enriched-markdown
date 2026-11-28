package com.swmansion.enriched.markdown.spans

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.text.Spannable
import android.text.TextPaint
import com.facebook.react.bridge.JavaOnlyArray
import com.facebook.react.bridge.JavaOnlyMap
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleMap
import com.swmansion.enriched.markdown.test.TestAstFactory.highlight
import com.swmansion.enriched.markdown.test.TestAstFactory.link
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.math.ceil
import kotlin.math.floor

// The inline icon covers the link's first word, which it draws itself; the rest of the link wraps as text.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class LinkIconSpanTest {
  @Test
  fun theIconCoversTheFirstWordAndLeavesTheTextAsItIs() {
    val rendered = renderLink(text(" Thread title here"))

    assertEquals("Thread", covered(rendered))
    assertEquals(" Thread title here", rendered.toString())
  }

  @Test
  fun theIconStopsWhereTheStyleChanges() {
    assertEquals("Thr", covered(renderLink(text("Thr"), highlight(text("ead")), text(" title"))))
  }

  @Test
  fun theIconKeepsAWholeEmojiAndOneCjkCharacter() {
    assertEquals("🚀", covered(renderLink(text("🚀 launch day"))))
    assertEquals("中", covered(renderLink(text("中文标题"))))
  }

  // A long unbroken token would otherwise be one unbreakable unit wider than a narrow line.
  @Test
  fun aLongWordIsCoveredOnlyAsFarAsEightFontSizes() {
    val word = "Averyveryveryverylongunbrokenidentifier"
    val rendered = renderLink(text(word))
    val run = covered(rendered)

    assertTrue(run.length in 2 until word.length)
    val paint = TextPaint().apply { textSize = FONT_SIZE }
    assertTrue(paint.measureText(run) <= FONT_SIZE * (8f - LinkIconSpan.ICON_SLOT_RATIO) + 1f)
  }

  // Bidi treats a replacement span as neutral, so the covered word could move in a right-to-left paragraph.
  // Each paragraph is checked for itself, so one with right-to-left text doesn't take the icon from another.
  @Test
  fun onlyTheRightToLeftParagraphLosesItsIcon() {
    val rendered =
      render(
        style(),
        paragraph(link(URL, text("First")), text(" and "), link(URL, text("Second"))),
        paragraph(text("שלום "), link(URL, text("Third"))),
      )

    val covered =
      rendered.getSpans(0, rendered.length, LinkIconSpan::class.java).map {
        rendered.subSequence(rendered.getSpanStart(it), rendered.getSpanEnd(it)).toString()
      }
    assertEquals(listOf("First", "Second"), covered.sorted())
  }

  // With no other strong letter, the covered word alone would set the paragraph's direction, and a
  // neutral replacement leaves it to the device.
  @Test
  fun aLoneWordKeepsItsIconOnALeftToRightDevice() {
    assertEquals("Docs", covered(render(style(), paragraph(link(URL, text("Docs"))))))
  }

  @Test
  @Config(qualifiers = "ar")
  fun aLoneWordLosesItsIconOnARightToLeftDevice() {
    assertNull(iconSpan(render(style(), paragraph(link(URL, text("Docs"))))))
    assertEquals("Docs", covered(render(style(), paragraph(link(URL, text("Docs")), text(" here")))))
  }

  @Test
  fun theIconTakesItsSlotBeforeTheWord() {
    val rendered = renderLink(text("Thread title"))
    val icon = iconSpan(rendered)!!
    val paint = TextPaint().apply { textSize = FONT_SIZE }
    val width = icon.getSize(paint, rendered, rendered.getSpanStart(icon), rendered.getSpanEnd(icon), null)

    assertEquals(ceil(FONT_SIZE * LinkIconSpan.ICON_SLOT_RATIO + paint.measureText("Thread")).toInt(), width)
    val bitmap = Bitmap.createBitmap(200, 40, Bitmap.Config.ARGB_8888)
    icon.draw(Canvas(bitmap), rendered, rendered.getSpanStart(icon), rendered.getSpanEnd(icon), 0f, 0, 30, 40, paint)
    val metrics = paint.fontMetrics
    val iconCentre = 30 + (metrics.ascent + metrics.descent) / 2
    assertEquals(Color.RED, bitmap.getPixel((FONT_SIZE / 2).toInt(), iconCentre.toInt()))
  }

  // A replacement span gets no background from its line, so the icon's word draws the variant's own,
  // and none when the variant has none, whatever an earlier run left on the line's paint.
  @Test
  fun theCoveredWordDrawsOnlyTheVariantBackground() {
    assertEquals(Color.RED, cornerAfterDrawing(renderLink(text("Thread title"), backgroundColor = Color.RED)))
    assertEquals(Color.TRANSPARENT, cornerAfterDrawing(renderLink(text("Thread title"))))
  }

  // A replacement span gets the line's baseline, so in a superscript it applies the run's shift itself
  // when drawing. When measuring it must not: the layout adds the shift to the measured line.
  @Test
  fun aSuperscriptIconIsDrawnShiftedAndMeasuredUnshifted() {
    val rendered = renderLink(text("Thread"))
    val icon = iconSpan(rendered)!!
    var baseline = Float.NaN
    val canvas =
      object : Canvas(Bitmap.createBitmap(200, 40, Bitmap.Config.ARGB_8888)) {
        override fun drawText(
          text: CharSequence,
          start: Int,
          end: Int,
          x: Float,
          y: Float,
          paint: Paint,
        ) {
          baseline = y
        }
      }
    val superscript =
      TextPaint().apply {
        textSize = SUPERSCRIPT_SIZE
        baselineShift = -6
      }
    icon.draw(canvas, rendered, rendered.getSpanStart(icon), rendered.getSpanEnd(icon), 0f, 0, 30, 40, superscript)
    assertEquals(24f, baseline)

    // The font-size icon is taller than the superscript text, so it sets the run's height.
    val fm = Paint.FontMetricsInt()
    icon.getSize(superscript, rendered, rendered.getSpanStart(icon), rendered.getSpanEnd(icon), fm)
    val text = superscript.fontMetricsInt
    val iconTop = floor((text.ascent + text.descent - FONT_SIZE) / 2).toInt()
    assertTrue(iconTop < text.ascent)
    assertEquals(iconTop, fm.ascent)
  }

  private fun cornerAfterDrawing(rendered: Spannable): Int {
    val icon = iconSpan(rendered)!!
    val linePaint =
      TextPaint().apply {
        textSize = FONT_SIZE
        bgColor = Color.GREEN
      }
    val bitmap = Bitmap.createBitmap(200, 40, Bitmap.Config.ARGB_8888)
    icon.draw(Canvas(bitmap), rendered, rendered.getSpanStart(icon), rendered.getSpanEnd(icon), 0f, 0, 30, 40, linePaint)
    return bitmap.getPixel(1, 1)
  }

  private fun renderLink(
    vararg children: MarkdownASTNode,
    backgroundColor: Int = Color.TRANSPARENT,
  ): Spannable = render(style(backgroundColor), paragraph(link(URL, *children)))

  private fun covered(rendered: Spannable): String {
    val icon = iconSpan(rendered)!!
    return rendered.subSequence(rendered.getSpanStart(icon), rendered.getSpanEnd(icon)).toString()
  }

  private fun iconSpan(rendered: Spannable): LinkIconSpan? = rendered.getSpans(0, rendered.length, LinkIconSpan::class.java).singleOrNull()

  private fun style(backgroundColor: Int = Color.TRANSPARENT): StyleConfig {
    val map = styleMap()
    map.putMap("link", (map.getMap("link") as JavaOnlyMap).apply { putString("fontFamily", "") })
    map.putArray(
      "linkVariants",
      JavaOnlyArray.of(
        JavaOnlyMap.of(
          "pattern",
          "^app://",
          "color",
          Color.BLUE,
          "underline",
          false,
          "backgroundColor",
          backgroundColor,
          "fontFamily",
          "",
          "inlineIcon",
          JavaOnlyMap.of("iconUri", ICON_URI),
        ),
      ),
    )
    return StyleConfig(map, RuntimeEnvironment.getApplication(), false, 0f)
  }

  private companion object {
    const val URL = "app://thread/1"
    const val FONT_SIZE = 16f
    const val SUPERSCRIPT_SIZE = 10f

    // A 4×4 opaque red PNG, so the icon loads synchronously and reserves its slot.
    const val ICON_URI =
      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAAEklEQVR4nGP4z8DwHxkzkC4AADxAH+HggXe0AAAAAElFTkSuQmCC"
  }
}
