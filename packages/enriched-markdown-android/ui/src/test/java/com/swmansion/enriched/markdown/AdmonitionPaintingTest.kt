package com.swmansion.enriched.markdown

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Rect
import android.text.Spannable
import android.text.StaticLayout
import android.text.TextPaint
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.AdmonitionHeaderSpan
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.test.HTMLGeneratorTestSupport
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.admonition
import com.swmansion.enriched.markdown.test.TestAstFactory.blockquote
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import kotlin.math.ceil

/**
 * Rasterizes the rendered document and inspects the pixels, so the box decoration is verified on
 * the canvas rather than through the span's fields.
 *
 * Scope note: Robolectric's graphics emulation does not fill — a `drawRect` comes out as a hairline
 * outline of the rect, and `drawPath` / `drawText` paint nothing at all. (Check this against a plain
 * blockquote before blaming a change: its accent bar renders as an outline here too.) So these
 * tests assert *which color* reaches the canvas and *where the header band sits*, which the outline
 * still carries faithfully. The header's icon and title glyphs cannot be asserted on pixels here;
 * their placement is pinned by the geometry tests in AdmonitionRendererTest instead.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class AdmonitionPaintingTest {
  private val quoteStyle get() = HTMLGeneratorTestSupport.defaultStyle.blockquoteStyle

  private companion object {
    const val WIDTH = 400
    const val NOTE = 0xFF0969DA.toInt()
    const val TIP = 0xFF1A7F37.toInt()
    const val WARNING = 0xFF9A6700.toInt()
    const val PLAIN_BORDER = 0xFFD1D5DB.toInt()
    const val PLAIN_BACKGROUND = 0xFFF9FAFB.toInt()
    const val NOTE_BACKGROUND = 0xFFDDF4FF.toInt()
    const val TIP_BACKGROUND = 0xFFDAFBE1.toInt()
  }

  private class Raster(
    val bitmap: Bitmap,
    val layout: StaticLayout,
  ) {
    /** Number of pixels of exactly [color] inside [region]. */
    fun count(
      color: Int,
      region: Rect,
    ): Int {
      var found = 0
      for (y in region.top until minOf(region.bottom, bitmap.height)) {
        for (x in region.left until minOf(region.right, bitmap.width)) {
          if (bitmap.getPixel(x, y) == color) found++
        }
      }
      return found
    }

    fun count(color: Int): Int = count(color, Rect(0, 0, bitmap.width, bitmap.height))

    /** The band occupied by the line that holds [content], clipped horizontally to [left]..[right]. */
    fun lineOf(
      content: String,
      left: Int = 0,
      right: Int = WIDTH,
    ): Rect {
      val line = layout.getLineForOffset(layout.text.toString().indexOf(content))
      return Rect(left, layout.getLineTop(line), right, layout.getLineBottom(line))
    }
  }

  private fun rasterize(
    document: MarkdownASTNode,
    style: StyleConfig = MarkdownRenderTestSupport.defaultStyle,
  ): Raster {
    val rendered = render(document, style)
    val layout =
      StaticLayout.Builder
        .obtain(rendered, 0, rendered.length, TextPaint().apply { textSize = quoteStyle.fontSize }, WIDTH)
        .build()

    val bitmap = Bitmap.createBitmap(WIDTH, maxOf(layout.height, 1), Bitmap.Config.ARGB_8888)
    Canvas(bitmap).also { layout.draw(it) }
    return Raster(bitmap, layout)
  }

  /** The line the admonition's header spacer sits on. */
  private fun headerBand(raster: Raster): Rect {
    val rendered = raster.layout.text as Spannable
    val header = rendered.getSpans(0, rendered.length, AdmonitionHeaderSpan::class.java).single()
    val line = raster.layout.getLineForOffset(rendered.getSpanStart(header))
    return Rect(0, raster.layout.getLineTop(line), WIDTH, raster.layout.getLineBottom(line))
  }

  @Test
  fun headerLineIsExactlyTheReservedHeight() {
    val raster = rasterize(document(admonition("warning", paragraph(text("Careful")))))
    val band = headerBand(raster)

    assertEquals(ceil(AdmonitionHeaderSpan("warning", quoteStyle).reservedHeight).toInt(), band.height())
  }

  @Test
  fun tintsTheAccentBarWithTheTypeColor() {
    val raster = rasterize(document(admonition("note", paragraph(text("Body")))))
    val barOnBodyLine = Rect(0, raster.layout.getLineTop(1), quoteStyle.borderWidth.toInt(), raster.layout.getLineBottom(1))

    assertTrue("Accent bar should carry the note tint", raster.count(NOTE, barOnBodyLine) > 0)
    assertEquals("No plain border color anywhere in an admonition", 0, raster.count(PLAIN_BORDER))
  }

  @Test
  fun eachTypeUsesItsOwnTint() {
    assertTrue(rasterize(document(admonition("note", paragraph(text("A"))))).count(NOTE) > 0)
    assertTrue(rasterize(document(admonition("tip", paragraph(text("A"))))).count(TIP) > 0)
    assertTrue(rasterize(document(admonition("warning", paragraph(text("A"))))).count(WARNING) > 0)

    assertEquals(0, rasterize(document(admonition("tip", paragraph(text("A"))))).count(NOTE))
  }

  @Test
  fun anAdmonitionIsUnfilledWhileAPlainQuoteKeepsItsBackground() {
    assertEquals(
      "Admonition backgrounds are opt-in, so nothing should be filled",
      0,
      rasterize(document(admonition("note", paragraph(text("Body"))))).count(PLAIN_BACKGROUND),
    )
    assertTrue(
      rasterize(document(blockquote(paragraph(text("Body"))))).count(PLAIN_BACKGROUND) > 0,
    )
  }

  @Test
  fun aPlainQuoteInsideAnAdmonitionKeepsItsOwnBarColor() {
    val raster = rasterize(document(admonition("note", blockquote(paragraph(text("Inner"))))))

    // Both bars are painted by the deepest span, each in the color of the level it belongs to.
    assertTrue("Outer admonition bar should be tinted", raster.count(NOTE) > 0)
    assertTrue("Inner plain quote bar should not be", raster.count(PLAIN_BORDER) > 0)
  }

  /** [quoteStyle] with the note and tip palettes filled, so nesting has two colors to tell apart. */
  private fun filledNoteAndTip(): StyleConfig {
    val base = MarkdownRenderTestSupport.defaultStyle.blockquoteStyle
    return MarkdownRenderTestSupport.styleWithBlockquote(
      base.copy(
        admonitions =
          base.admonitions.mapValues { (type, colors) ->
            when (type) {
              "note" -> colors.copy(backgroundColor = NOTE_BACKGROUND)
              "tip" -> colors.copy(backgroundColor = TIP_BACKGROUND)
              else -> colors
            }
          },
      ),
    )
  }

  @Test
  fun aNestedAdmonitionIsFilledWithItsOwnColorInsideItsParents() {
    val raster =
      rasterize(
        document(admonition("tip", admonition("note", paragraph(text("Inner"))))),
        filledNoteAndTip(),
      )
    val levelSpacing = (quoteStyle.borderWidth + quoteStyle.gapWidth).toInt()

    assertTrue("Nested admonition should paint its own fill", raster.count(NOTE_BACKGROUND) > 0)
    assertEquals(
      "Nested fill should start at its own accent bar, not at the parent's",
      0,
      raster.count(NOTE_BACKGROUND, raster.lineOf("Inner", right = levelSpacing)),
    )
    assertTrue(
      "Parent fill should still frame the nested one",
      raster.count(TIP_BACKGROUND, raster.lineOf("Inner", right = levelSpacing)) > 0,
    )
  }

  @Test
  fun aListNestedAdmonitionPaintsNoTint() {
    val raster =
      rasterize(document(unorderedList(listItem(admonition("caution", paragraph(text("Nested")))))))

    assertEquals(
      "A list-nested admonition falls back to plain blockquote colors",
      0,
      raster.count(0xFFCF222E.toInt()),
    )
    assertTrue(raster.count(PLAIN_BORDER) > 0)
  }
}
