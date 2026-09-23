package com.swmansion.enriched.markdown.input.styles

import com.facebook.react.views.text.TextAttributes
import com.swmansion.enriched.markdown.input.model.BlockRange
import com.swmansion.enriched.markdown.input.model.BlockType
import com.swmansion.enriched.markdown.input.model.InputFormatterStyle
import com.swmansion.enriched.markdown.input.spans.InputHeadingSpan

/**
 * Block handler for ATX headings (H1-H6). A single instance serves all six levels:
 * it reads the H-level from each [BlockRange.level], so it is registered in the
 * [com.swmansion.enriched.markdown.input.formatting.InputFormatter] under every
 * `HEADING_n` key. The level — not [blockType] — drives styling and serialization,
 * so [blockType] is only a nominal interface value and never consulted by the
 * formatter (it dispatches on `range.type`).
 */
class HeadingBlockHandler : BlockHandler {
  override val blockType: BlockType = BlockType.HEADING_1

  override fun createSpans(
    blockRange: BlockRange,
    style: InputFormatterStyle,
    bodyTextAttributes: TextAttributes,
  ): List<Any> {
    val headingStyle = style.headingStyle(blockRange.level)
    val bodyFontSizeSp = bodyTextAttributes.fontSize
    val bodyLineHeightSp = bodyTextAttributes.lineHeight
    // Without a body lineHeight every line keeps its font's natural height,
    // headings included.
    val lineHeightPx =
      if (bodyLineHeightSp.isNaN() || !(bodyFontSizeSp > 0f)) {
        null
      } else {
        // The heading keeps the body's extra leading (lineHeight - fontSize) on
        // top of its own font size. Convert its px size back to SP so it goes
        // through the same font scaling as the body line height.
        val headingFontSizeSp =
          headingStyle.fontSizePx?.let { it / bodyTextAttributes.effectiveFontSize * bodyFontSizeSp }
            ?: bodyFontSizeSp
        TextAttributes()
          .apply {
            allowFontScaling = bodyTextAttributes.allowFontScaling
            fontSize = headingFontSizeSp
            lineHeight = headingFontSizeSp + (bodyLineHeightSp - bodyFontSizeSp)
          }.effectiveLineHeight
      }
    return listOf(InputHeadingSpan(blockRange.level, style, lineHeightPx))
  }

  override fun spanClasses(): List<Class<*>> = listOf(InputHeadingSpan::class.java)

  override fun markdownLinePrefix(blockRange: BlockRange): String = "#".repeat(blockRange.level.coerceIn(1, 6)) + " "
}
