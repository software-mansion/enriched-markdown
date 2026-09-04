package com.swmansion.enriched.markdown.styles

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class StyleConfigTest {
  @Test
  fun equalConfigsWithDifferentTypefaceInstancesAreEqual() {
    val first =
      StyleConfig(
        paragraphStyleDefault = sampleParagraph(),
        headingStyles = arrayOf(null, sampleHeading()),
        headingTypefaces = arrayOf(null, null),
        linkStyle = sampleLink(),
        strongStyle = StrongStyle(fontFamily = "", fontWeight = "bold", color = null),
        emphasisStyle = EmphasisStyle(fontFamily = "", fontStyle = "italic", color = null),
        superscriptStyle = sampleSuperscript(),
        subscriptStyle = sampleSubscript(),
        codeStyle = sampleCode(),
        imageStyle = sampleImage(),
        inlineImageStyle = InlineImageStyle(size = 20f),
        blockquoteStyle = sampleBlockquote(),
        listStyle = sampleList(),
        codeBlockStyle = sampleCodeBlock(),
        thematicBreakStyle = sampleThematicBreak(),
      )

    val second =
      StyleConfig(
        paragraphStyleDefault = sampleParagraph(),
        headingStyles = arrayOf(null, sampleHeading()),
        headingTypefaces = arrayOf(null, null),
        linkStyle = sampleLink(),
        strongStyle = StrongStyle(fontFamily = "", fontWeight = "bold", color = null),
        emphasisStyle = EmphasisStyle(fontFamily = "", fontStyle = "italic", color = null),
        superscriptStyle = sampleSuperscript(),
        subscriptStyle = sampleSubscript(),
        codeStyle = sampleCode(),
        imageStyle = sampleImage(),
        inlineImageStyle = InlineImageStyle(size = 20f),
        blockquoteStyle = sampleBlockquote(),
        listStyle = sampleList(),
        codeBlockStyle = sampleCodeBlock(),
        thematicBreakStyle = sampleThematicBreak(),
      )

    assertEquals(first, second)
    assertEquals(first.hashCode(), second.hashCode())
  }

  @Test
  fun differentParagraphColorsAreNotEqual() {
    val first = sampleConfig()
    val second =
      StyleConfig(
        paragraphStyleDefault = sampleParagraph(color = 0xFF000000.toInt()),
        headingStyles = arrayOf(null, sampleHeading()),
        headingTypefaces = arrayOf(null, null),
        linkStyle = sampleLink(),
        strongStyle = StrongStyle(fontFamily = "", fontWeight = "bold", color = null),
        emphasisStyle = EmphasisStyle(fontFamily = "", fontStyle = "italic", color = null),
        superscriptStyle = sampleSuperscript(),
        subscriptStyle = sampleSubscript(),
        codeStyle = sampleCode(),
        imageStyle = sampleImage(),
        inlineImageStyle = InlineImageStyle(size = 20f),
        blockquoteStyle = sampleBlockquote(),
        listStyle = sampleList(),
        codeBlockStyle = sampleCodeBlock(),
        thematicBreakStyle = sampleThematicBreak(),
      )

    assertFalse(first == second)
  }

  private fun sampleConfig(): StyleConfig =
    StyleConfig(
      paragraphStyleDefault = sampleParagraph(),
      headingStyles = arrayOf(null, sampleHeading()),
      headingTypefaces = arrayOf(null, null),
      linkStyle = sampleLink(),
      strongStyle = StrongStyle(fontFamily = "", fontWeight = "bold", color = null),
      emphasisStyle = EmphasisStyle(fontFamily = "", fontStyle = "italic", color = null),
      superscriptStyle = sampleSuperscript(),
      subscriptStyle = sampleSubscript(),
      codeStyle = sampleCode(),
      imageStyle = sampleImage(),
      inlineImageStyle = InlineImageStyle(size = 20f),
      blockquoteStyle = sampleBlockquote(),
      listStyle = sampleList(),
      codeBlockStyle = sampleCodeBlock(),
      thematicBreakStyle = sampleThematicBreak(),
    )

  private fun sampleParagraph(color: Int = 0xFF112233.toInt()) =
    ParagraphStyle(
      fontSize = 16f,
      fontFamily = "sans-serif",
      fontWeight = "",
      color = color,
      marginTop = 0f,
      marginBottom = 16f,
      lineHeight = 26f,
      textAlign = TextAlignment.AUTO,
    )

  private fun sampleHeading() =
    HeadingStyle(
      fontSize = 24f,
      fontFamily = "sans-serif",
      fontWeight = "bold",
      color = 0xFF111111.toInt(),
      marginTop = 0f,
      marginBottom = 8f,
      lineHeight = 32f,
      textAlign = TextAlignment.AUTO,
    )

  private fun sampleLink() =
    LinkStyle(
      fontFamily = "",
      color = 0xFF2563EB.toInt(),
      underline = true,
      backgroundColor = 0,
    )

  private fun sampleCode() =
    CodeStyle(
      fontFamily = "",
      fontSize = 14f,
      color = 0xFF7C3AED.toInt(),
      backgroundColor = 0xFFF5F3FF.toInt(),
      borderColor = 0xFFDDD6FE.toInt(),
    )

  private fun sampleSuperscript() = SuperscriptStyle(fontScale = 0.65f, baselineOffsetScale = 0.35f)

  private fun sampleSubscript() = SubscriptStyle(fontScale = 0.65f, baselineOffsetScale = 0.2f)

  private fun sampleImage() =
    ImageStyle(
      height = 200f,
      borderRadius = 8f,
      marginTop = 0f,
      marginBottom = 16f,
    )

  private fun sampleBlockquote() =
    BlockquoteStyle(
      fontSize = 16f,
      fontFamily = "sans-serif",
      fontWeight = "",
      color = 0xFF4B5563.toInt(),
      marginTop = 0f,
      marginBottom = 16f,
      lineHeight = 26f,
      borderColor = 0xFFD1D5DB.toInt(),
      borderWidth = 3f,
      gapWidth = 16f,
      backgroundColor = 0xFFF9FAFB.toInt(),
    )

  private fun sampleList() =
    ListStyle(
      fontSize = 16f,
      fontFamily = "sans-serif",
      fontWeight = "",
      color = 0xFF1F2937.toInt(),
      marginTop = 0f,
      marginBottom = 16f,
      lineHeight = 26f,
      bulletColor = 0xFF6B7280.toInt(),
      bulletSize = 6f,
      markerMinWidth = 20f,
      markerColor = 0xFF6B7280.toInt(),
      markerFontWeight = "500",
      gapWidth = 8f,
      marginLeft = 24f,
    )

  private fun sampleCodeBlock() =
    CodeBlockStyle(
      fontSize = 14f,
      fontFamily = "monospace",
      fontWeight = "",
      color = 0xFFF3F4F6.toInt(),
      marginTop = 0f,
      marginBottom = 16f,
      lineHeight = 22f,
      backgroundColor = 0xFF1F2937.toInt(),
      borderColor = 0xFF374151.toInt(),
      borderRadius = 8f,
      borderWidth = 1f,
      padding = 16f,
    )

  private fun sampleThematicBreak() =
    ThematicBreakStyle(
      color = 0xFFE5E7EB.toInt(),
      height = 1f,
      marginTop = 24f,
      marginBottom = 24f,
    )
}
