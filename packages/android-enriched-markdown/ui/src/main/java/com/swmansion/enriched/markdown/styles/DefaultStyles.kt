package com.swmansion.enriched.markdown.styles

import android.content.Context
import com.swmansion.enriched.markdown.utils.text.TypefaceUtils

internal object DefaultStyles {
  private const val SYSTEM_FONT = "sans-serif"
  private const val MONOSPACE_FONT = "monospace"

  fun create(
    context: Context,
    allowFontScaling: Boolean = true,
    maxFontSizeMultiplier: Float = 0f,
  ): StyleConfig {
    val parser = StyleParser(context, allowFontScaling, maxFontSizeMultiplier)

    val paragraphStyle =
      ParagraphStyle(
        fontSize = parser.toPixelFromSP(16f),
        fontFamily = SYSTEM_FONT,
        fontWeight = "",
        color = parser.color("#1F2937"),
        marginTop = parser.toPixelFromDIP(0f),
        marginBottom = parser.toPixelFromDIP(16f),
        lineHeight = parser.toPixelFromSP(26f),
        textAlign = TextAlignment.AUTO,
      )

    fun heading(
      fontSizeSp: Float,
      lineHeightSp: Float,
      color: String,
      marginBottom: Float = 8f,
    ): HeadingStyle =
      HeadingStyle(
        fontSize = parser.toPixelFromSP(fontSizeSp),
        fontFamily = SYSTEM_FONT,
        fontWeight = "",
        color = parser.color(color),
        marginTop = parser.toPixelFromDIP(0f),
        marginBottom = parser.toPixelFromDIP(marginBottom),
        lineHeight = parser.toPixelFromSP(lineHeightSp),
        textAlign = TextAlignment.AUTO,
      )

    val headingStyles =
      arrayOf<HeadingStyle?>(
        null,
        heading(30f, 38f, "#111827"),
        heading(24f, 32f, "#111827"),
        heading(20f, 28f, "#111827"),
        heading(18f, 26f, "#111827"),
        heading(16f, 24f, "#374151"),
        heading(14f, 22f, "#4B5563"),
      )

    val headingTypefaces =
      Array(7) { level ->
        if (level == 0) {
          null
        } else {
          val style = headingStyles[level] ?: return@Array null
          TypefaceUtils.applyStyles(context, style.fontFamily, style.fontWeight)
        }
      }

    return StyleConfig(
      paragraphStyleDefault = paragraphStyle,
      headingStyles = headingStyles,
      headingTypefaces = headingTypefaces,
      linkStyle =
        LinkStyle(
          fontFamily = "",
          color = parser.color("#2563EB"),
          underline = true,
          backgroundColor = parser.color("#00000000"),
        ),
      strongStyle = StrongStyle(fontFamily = "", fontWeight = "bold", color = null),
      emphasisStyle = EmphasisStyle(fontFamily = "", fontStyle = "italic", color = null),
      codeStyle =
        CodeStyle(
          fontFamily = "",
          fontSize = 0f,
          color = parser.color("#E01E5A"),
          backgroundColor = parser.color("#FDF2F4"),
          borderColor = parser.color("#F8D7DA"),
        ),
      imageStyle =
        ImageStyle(
          height = parser.toPixelFromDIP(200f),
          borderRadius = parser.toPixelFromDIP(8f),
          marginTop = parser.toPixelFromDIP(0f),
          marginBottom = parser.toPixelFromDIP(16f),
        ),
      inlineImageStyle = InlineImageStyle(size = parser.toPixelFromDIP(20f)),
      blockquoteStyle =
        BlockquoteStyle(
          fontSize = parser.toPixelFromSP(16f),
          fontFamily = SYSTEM_FONT,
          fontWeight = "",
          color = parser.color("#4B5563"),
          marginTop = parser.toPixelFromDIP(0f),
          marginBottom = parser.toPixelFromDIP(16f),
          lineHeight = parser.toPixelFromSP(26f),
          borderColor = parser.color("#D1D5DB"),
          borderWidth = parser.toPixelFromDIP(3f),
          gapWidth = parser.toPixelFromDIP(16f),
          backgroundColor = parser.color("#F9FAFB"),
          borderRadius = 0f,
          padding = 0f,
        ),
      listStyle =
        ListStyle(
          fontSize = parser.toPixelFromSP(16f),
          fontFamily = SYSTEM_FONT,
          fontWeight = "",
          color = parser.color("#1F2937"),
          marginTop = parser.toPixelFromDIP(0f),
          marginBottom = parser.toPixelFromDIP(16f),
          lineHeight = parser.toPixelFromSP(26f),
          bulletColor = parser.color("#6B7280"),
          bulletSize = parser.toPixelFromDIP(6f),
          markerMinWidth = parser.toPixelFromDIP(0f),
          markerColor = parser.color("#6B7280"),
          markerFontWeight = "500",
          gapWidth = parser.toPixelFromDIP(12f),
          marginLeft = parser.toPixelFromDIP(24f),
        ),
      codeBlockStyle =
        CodeBlockStyle(
          fontSize = parser.toPixelFromSP(14f),
          fontFamily = MONOSPACE_FONT,
          fontWeight = "",
          color = parser.color("#F3F4F6"),
          marginTop = parser.toPixelFromDIP(0f),
          marginBottom = parser.toPixelFromDIP(16f),
          lineHeight = parser.toPixelFromSP(22f),
          backgroundColor = parser.color("#1F2937"),
          borderColor = parser.color("#374151"),
          borderRadius = parser.toPixelFromDIP(8f),
          borderWidth = parser.toPixelFromDIP(1f),
          padding = parser.toPixelFromDIP(16f),
        ),
      thematicBreakStyle =
        ThematicBreakStyle(
          color = parser.color("#E5E7EB"),
          height = parser.toPixelFromDIP(1f),
          marginTop = parser.toPixelFromDIP(24f),
          marginBottom = parser.toPixelFromDIP(24f),
        ),
    )
  }
}
