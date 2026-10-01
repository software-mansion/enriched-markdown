package com.swmansion.enriched.markdown

import android.graphics.Color
import android.text.Spanned
import android.text.TextPaint
import android.text.style.CharacterStyle
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.spans.EmphasisSpan
import com.swmansion.enriched.markdown.spans.LinkSpan
import com.swmansion.enriched.markdown.spans.SpoilerSpan
import com.swmansion.enriched.markdown.spans.StrongSpan
import com.swmansion.enriched.markdown.test.HTMLAssertions.assertContainsHtml
import com.swmansion.enriched.markdown.test.HTMLGeneratorTestSupport
import com.swmansion.enriched.markdown.test.MarkdownExtractorTestSupport
import com.swmansion.enriched.markdown.test.MarkdownRenderAssertions.assertContains
import com.swmansion.enriched.markdown.test.MarkdownRenderAssertions.assertSpanCovers
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.code
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.emphasis
import com.swmansion.enriched.markdown.test.TestAstFactory.link
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.spoiler
import com.swmansion.enriched.markdown.test.TestAstFactory.strong
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class SpoilerRendererTest {
  @Test
  fun spoilerSpanCoversOnlyTheConcealedText() {
    val rendered =
      render(
        document(
          paragraph(
            text("before "),
            spoiler(text("secret")),
            text(" after"),
          ),
        ),
      )

    rendered.assertContains("before secret after")
    rendered.assertSpanCovers("secret", SpoilerSpan::class.java)

    val span = rendered.getSpans(0, rendered.length, SpoilerSpan::class.java).single()
    val start = rendered.toString().indexOf("secret")
    assertEquals(start, rendered.getSpanStart(span))
    assertEquals(start + "secret".length, rendered.getSpanEnd(span))
  }

  /**
   * Regression: a Spoiler node used to fall through to TextRenderer, which renders the node's own
   * (empty) content and never recurses, so `||secret||` rendered as nothing at all.
   */
  @Test
  fun spoilerChildrenAreRenderedRatherThanDropped() {
    val rendered = render(document(paragraph(spoiler(text("hidden words")))))

    rendered.assertContains("hidden words")
    assertEquals(1, rendered.getSpans(0, rendered.length, SpoilerSpan::class.java).size)
  }

  @Test
  fun inlineStylesInsideASpoilerSurvive() {
    val rendered =
      render(
        document(
          paragraph(
            spoiler(
              strong(text("bold")),
              text(" and "),
              emphasis(text("italic")),
            ),
          ),
        ),
      )

    rendered.assertContains("bold and italic")
    rendered.assertSpanCovers("bold", StrongSpan::class.java)
    rendered.assertSpanCovers("italic", EmphasisSpan::class.java)
    rendered.assertSpanCovers("bold and italic", SpoilerSpan::class.java)
  }

  @Test
  fun inlineCodeInsideASpoilerKeepsItsOwnSize() {
    val defaults = MarkdownRenderTestSupport.defaultStyle
    val codeSize = defaults.paragraphStyle.fontSize - 5f
    val style = MarkdownRenderTestSupport.styleWithCode(defaults.codeStyle.copy(fontSize = codeSize))

    val plain = render(document(paragraph(code("x"))), style).drawStateAt("x")
    val concealed = render(document(paragraph(spoiler(code("x")))), style).drawStateAt("x")

    assertEquals(codeSize, plain.textSize, 0.001f)
    assertEquals(codeSize, concealed.textSize, 0.001f)
  }

  @Test
  fun concealedTextIsDrawnTransparent() {
    val rendered = render(document(paragraph(spoiler(text("secret")))))

    assertEquals(0, Color.alpha(rendered.drawStateAt("secret").color))
  }

  @Test
  fun wrappersThatRecolorTheRunDoNotUncoverIt() {
    val rendered =
      render(
        document(
          paragraph(
            link("https://example.com", spoiler(text("linked"))),
            strong(spoiler(code("coded"))),
          ),
        ),
      )

    listOf("linked", "coded").forEach { run ->
      val paint = rendered.drawStateAt(run)
      assertEquals("$run should stay concealed", 0, Color.alpha(paint.color))
      assertEquals("$run should stay concealed", 0, Color.alpha(paint.linkColor))
    }
  }

  @Test
  fun aRevealedSpoilerDrawsItsTextInTheBlockColor() {
    val rendered = render(document(paragraph(spoiler(text("secret")))))
    rendered.getSpans(0, rendered.length, SpoilerSpan::class.java).single().markRevealed()

    val plain = render(document(paragraph(text("secret")))).drawStateAt("secret")
    assertEquals(plain.color, rendered.drawStateAt("secret").color)
  }

  @Test
  fun aLinkInsideASpoilerKeepsItsUrl() {
    val rendered =
      render(document(paragraph(spoiler(link("https://example.com", text("tap"))))))

    rendered.assertSpanCovers("tap", SpoilerSpan::class.java)
    assertEquals(
      "https://example.com",
      rendered
        .getSpans(0, rendered.length, LinkSpan::class.java)
        .single()
        .url,
    )
  }

  @Test
  fun anEmptySpoilerProducesNoSpan() {
    val rendered = render(document(paragraph(spoiler())))

    assertEquals(0, rendered.getSpans(0, rendered.length, SpoilerSpan::class.java).size)
  }

  @Test
  fun adjacentSpoilersStayIndependentSpans() {
    val rendered =
      render(
        document(
          paragraph(
            spoiler(text("one")),
            text(" "),
            spoiler(text("two")),
          ),
        ),
      )

    assertEquals(2, rendered.getSpans(0, rendered.length, SpoilerSpan::class.java).size)
  }

  @Test
  fun aFreshSpanIsNeitherRevealingNorRevealed() {
    val rendered = render(document(paragraph(spoiler(text("secret")))))
    val span = rendered.getSpans(0, rendered.length, SpoilerSpan::class.java).single()

    assertFalse(span.revealed)
    assertFalse(span.revealing)
  }

  @Test
  fun theSpanCarriesTheBlockFontSize() {
    val rendered = render(document(paragraph(spoiler(text("secret")))))
    val span = rendered.getSpans(0, rendered.length, SpoilerSpan::class.java).single()

    assertEquals(
      MarkdownRenderTestSupport.defaultStyle.paragraphStyle.fontSize,
      span.blockStyle.fontSize,
      0.001f,
    )
  }

  @Test
  fun theStyleCacheExposesTheSpoilerPalette() {
    val style = MarkdownRenderTestSupport.defaultStyle.spoilerStyle

    assertEquals(0xFF374151.toInt(), style.color)
    assertEquals(8f, style.particleDensity, 0.001f)
    assertEquals(20f, style.particleSpeed, 0.001f)
    assertTrue("Solid radius is stored in pixels", style.solidCornerRadius > 0f)
  }

  // MARK: Copy / export

  @Test
  fun copyingASpoilerKeepsItsMarkers() {
    val markdown =
      MarkdownExtractorTestSupport.extractFromFullSelection(
        document(paragraph(spoiler(text("secret")))),
      )

    assertNotNull(markdown)
    assertTrue(
      "Expected the spoiler markers, but was: \"$markdown\"",
      markdown!!.contains("||secret||"),
    )
  }

  @Test
  fun spoilerMarkersWrapTheInlineFormattingInside() {
    val markdown =
      MarkdownExtractorTestSupport.extractFromFullSelection(
        document(paragraph(spoiler(strong(text("loud"))))),
      )

    assertNotNull(markdown)
    assertTrue(
      "Expected the markers outside the bold, but was: \"$markdown\"",
      markdown!!.contains("||**loud**||"),
    )
  }

  @Test
  fun aPartialSelectionStillRoundTripsTheMarkers() {
    val markdown =
      MarkdownExtractorTestSupport.extractSelectingText(
        document(paragraph(text("before "), spoiler(text("secret")), text(" after"))),
        "secret",
      )

    assertEquals("||secret||", markdown)
  }

  @Test
  fun plainTextNextToASpoilerIsNotWrapped() {
    val markdown =
      MarkdownExtractorTestSupport.extractFromFullSelection(
        document(paragraph(text("before "), spoiler(text("secret")), text(" after"))),
      )

    assertNotNull(markdown)
    assertEquals("before ||secret|| after", markdown!!.trim())
  }

  @Test
  fun htmlExportsASpoilerAsPlainText() {
    val html =
      HTMLGeneratorTestSupport.generateHTML(render(document(paragraph(spoiler(text("secret"))))))

    // Matches the React Native package, which leaves spoilers out of the HTML export.
    html.assertContainsHtml("secret")
    assertFalse(html.contains("data-spoiler"))
  }

  /** The paint a run is drawn with: every character style over it, applied in span order. */
  private fun Spanned.drawStateAt(run: String): TextPaint {
    val start = toString().indexOf(run)
    val paint = TextPaint().apply { color = Color.BLACK }
    getSpans(start, start + run.length, CharacterStyle::class.java).forEach { it.updateDrawState(paint) }
    return paint
  }
}
