package com.swmansion.enriched.markdown

import android.graphics.Paint
import android.text.StaticLayout
import android.text.TextPaint
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.spans.AdmonitionHeaderSpan
import com.swmansion.enriched.markdown.spans.AdmonitionIcons
import com.swmansion.enriched.markdown.spans.BlockquoteSpan
import com.swmansion.enriched.markdown.test.HTMLAssertions.assertContainsHtml
import com.swmansion.enriched.markdown.test.HTMLGeneratorTestSupport
import com.swmansion.enriched.markdown.test.MarkdownExtractorTestSupport
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.admonition
import com.swmansion.enriched.markdown.test.TestAstFactory.blockquote
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.roundToInt

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class AdmonitionRendererTest {
  private val blockquoteStyle get() = HTMLGeneratorTestSupport.defaultStyle.blockquoteStyle

  private fun headerSpanOf(document: com.swmansion.enriched.markdown.parser.MarkdownASTNode): AdmonitionHeaderSpan? {
    val rendered = render(document)
    return rendered.getSpans(0, rendered.length, AdmonitionHeaderSpan::class.java).firstOrNull()
  }

  @Test
  fun reservesAHeaderForATopLevelAdmonition() {
    val rendered = render(document(admonition("warning", paragraph(text("Mind the gap")))))

    val headers = rendered.getSpans(0, rendered.length, AdmonitionHeaderSpan::class.java)
    assertEquals(1, headers.size)
    assertEquals("warning", headers[0].type)
    assertEquals("Warning", headers[0].title)

    // The header spacer is the first character of the quote, so the box opens on the header line.
    val quote = rendered.getSpans(0, rendered.length, BlockquoteSpan::class.java).single()
    assertEquals(rendered.getSpanStart(quote), rendered.getSpanStart(headers[0]))
    assertTrue("Header must sit inside the quote", rendered.getSpanEnd(headers[0]) <= rendered.getSpanEnd(quote))
  }

  @Test
  fun headerOccupiesItsOwnSpacerLine() {
    val rendered = render(document(admonition("note", paragraph(text("Body")))))
    val header = rendered.getSpans(0, rendered.length, AdmonitionHeaderSpan::class.java).single()

    val start = rendered.getSpanStart(header)
    assertEquals(start + 1, rendered.getSpanEnd(header))
    assertEquals('\n', rendered[start])
    // The spacer carries no text of its own: the body still starts at the next character.
    assertTrue(rendered.toString().startsWith("\nBody"))
  }

  @Test
  fun headerHeightMatchesTheReactNativeGeometry() {
    val style = blockquoteStyle
    val header = AdmonitionHeaderSpan("note", style)

    val expectedContent = ceil(max(ceil(style.fontSize), style.fontSize * 1.35f))
    val expectedReserved = expectedContent + (style.fontSize * 0.4f).roundToInt()

    assertEquals(expectedContent, header.contentHeight, 0.001f)
    assertEquals(expectedReserved, header.reservedHeight, 0.001f)
  }

  @Test
  fun headerLineIsFixedToTheReservedHeight() {
    val style = blockquoteStyle
    val header = AdmonitionHeaderSpan("note", style)
    val metrics =
      Paint.FontMetricsInt().apply {
        ascent = -40
        descent = 10
        top = -50
        bottom = 20
      }

    header.chooseHeight("\n", 0, 1, 0, 0, metrics)

    val expected = ceil(header.reservedHeight).toInt()
    assertEquals(0, metrics.top)
    assertEquals(0, metrics.ascent)
    assertEquals(expected, metrics.descent)
    assertEquals(expected, metrics.bottom)
  }

  @Test
  fun everyAlertTypeHasItsGitHubColorByDefault() {
    val palette = blockquoteStyle.admonitions

    assertEquals(AdmonitionIcons.TYPES, palette.keys)
    assertEquals(0xFF0969DA.toInt(), palette.getValue("note").color)
    assertEquals(0xFF1A7F37.toInt(), palette.getValue("tip").color)
    assertEquals(0xFF8250DF.toInt(), palette.getValue("important").color)
    assertEquals(0xFF9A6700.toInt(), palette.getValue("warning").color)
    assertEquals(0xFFCF222E.toInt(), palette.getValue("caution").color)

    // Backgrounds are opt-in: the box is unfilled unless the user sets one.
    assertTrue(palette.values.all { it.backgroundColor == null })
  }

  @Test
  fun everyAlertTypeHasAnIconAndATitle() {
    for (type in AdmonitionIcons.TYPES) {
      assertNotNull("Missing icon for $type", AdmonitionIcons.path(type))
      assertEquals(type.replaceFirstChar { it.uppercase() }, AdmonitionIcons.title(type))
    }
  }

  @Test
  fun anAdmonitionNestedInAListFallsBackToAPlainQuote() {
    val rendered =
      render(
        document(
          unorderedList(listItem(admonition("caution", paragraph(text("Nested"))))),
        ),
      )

    assertEquals(
      "A list-nested admonition renders as a plain quote, matching both React Native renderers",
      0,
      rendered.getSpans(0, rendered.length, AdmonitionHeaderSpan::class.java).size,
    )
    assertTrue(rendered.getSpans(0, rendered.length, BlockquoteSpan::class.java).isNotEmpty())
  }

  @Test
  fun anAdmonitionKeepsItsBottomMarginWhenTheNextOneOpensWithANestedBox() {
    val rendered =
      render(
        document(
          admonition("note", paragraph(text("First"))),
          admonition("tip", admonition("note", paragraph(text("Inner")))),
        ),
      )
    val layout =
      StaticLayout.Builder
        .obtain(rendered, 0, rendered.length, TextPaint().apply { textSize = blockquoteStyle.fontSize }, 400)
        .build()

    val boxStarts =
      rendered
        .getSpans(0, rendered.length, BlockquoteSpan::class.java)
        .filter { it.depth == 0 }
        .map { rendered.getSpanStart(it) }
        .sorted()
    assertEquals(2, boxStarts.size)

    // The character before the second box is the first one's bottom-margin spacer, on a line of its
    // own. The nested box stacks two header spacers right after it, which used to read as the end of
    // the document and collapse that line to nothing.
    val gapLine = layout.getLineForOffset(boxStarts[1] - 1)
    assertEquals(
      blockquoteStyle.marginBottom.toInt(),
      layout.getLineBottom(gapLine) - layout.getLineTop(gapLine),
    )
  }

  @Test
  fun anAdmonitionNestedInAQuoteKeepsItsHeader() {
    val rendered =
      render(document(blockquote(admonition("tip", paragraph(text("Inner"))))))

    val header = rendered.getSpans(0, rendered.length, AdmonitionHeaderSpan::class.java).single()
    assertEquals("tip", header.type)
    assertEquals(2, rendered.getSpans(0, rendered.length, BlockquoteSpan::class.java).size)
  }

  @Test
  fun aPlainQuoteHasNoHeader() {
    assertNull(headerSpanOf(document(blockquote(paragraph(text("Just a quote"))))))
  }

  @Test
  fun anAdmonitionWithNoBodyRendersNothing() {
    val rendered = render(document(admonition("important")))

    assertEquals(0, rendered.length)
    assertEquals(0, rendered.getSpans(0, rendered.length, AdmonitionHeaderSpan::class.java).size)
  }

  @Test
  fun anUnknownTypeDegradesToACapitalizedTitleWithNoIcon() {
    val header = AdmonitionHeaderSpan("heads-up", blockquoteStyle)

    assertEquals("Heads-up", header.title)
    assertNull(AdmonitionIcons.path("heads-up"))
  }

  @Test
  fun copyingAnAdmonitionRoundTripsItsMarker() {
    val markdown =
      MarkdownExtractorTestSupport.extractFromFullSelection(
        document(admonition("note", paragraph(text("Remember this")))),
      )

    assertNotNull(markdown)
    assertTrue(
      "Expected the [!NOTE] marker and its body, but was: \"$markdown\"",
      markdown!!.contains("> [!NOTE]\n> Remember this"),
    )
  }

  @Test
  fun copyingANestedAdmonitionRepeatsTheQuoteMarkers() {
    val markdown =
      MarkdownExtractorTestSupport.extractFromFullSelection(
        document(blockquote(admonition("caution", paragraph(text("Deep"))))),
      )

    assertNotNull(markdown)
    assertTrue(
      "Expected a depth-2 marker, but was: \"$markdown\"",
      markdown!!.contains("> > [!CAUTION]"),
    )
  }

  @Test
  fun htmlCarriesTheHeaderAndTheTypeTint() {
    val rendered = render(document(admonition("warning", paragraph(text("Careful")))))
    val html = HTMLGeneratorTestSupport.generateHTML(rendered)

    // #9A6700 is the GitHub warning color, applied to both the accent bar and the title.
    html.assertContainsHtml("border-inline-start: 3px solid #9A6700")
    html.assertContainsHtml("font-weight: 700;\">Warning</p>")
    html.assertContainsHtml("Careful")
  }

  @Test
  fun htmlLeavesAnAdmonitionUnfilledWhileAPlainQuoteKeepsItsBackground() {
    val admonitionHtml = HTMLGeneratorTestSupport.generateHTML(render(document(admonition("note", paragraph(text("A"))))))
    val quoteHtml = HTMLGeneratorTestSupport.generateHTML(render(document(blockquote(paragraph(text("A"))))))

    admonitionHtml.assertContainsHtml("background-color: transparent")
    quoteHtml.assertContainsHtml("background-color: #F9FAFB")
  }
}
