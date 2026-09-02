package com.swmansion.enriched.markdown.compose.style

import com.swmansion.enriched.markdown.styles.BlockquoteStyle
import com.swmansion.enriched.markdown.styles.CodeBlockStyle
import com.swmansion.enriched.markdown.styles.CodeStyle
import com.swmansion.enriched.markdown.styles.EmphasisStyle
import com.swmansion.enriched.markdown.styles.HeadingStyle
import com.swmansion.enriched.markdown.styles.ImageStyle
import com.swmansion.enriched.markdown.styles.InlineImageStyle
import com.swmansion.enriched.markdown.styles.LinkStyle
import com.swmansion.enriched.markdown.styles.ListStyle
import com.swmansion.enriched.markdown.styles.ParagraphStyle
import com.swmansion.enriched.markdown.styles.StrongStyle
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.SubscriptStyle
import com.swmansion.enriched.markdown.styles.SuperscriptStyle
import com.swmansion.enriched.markdown.styles.ThematicBreakStyle
import com.swmansion.enriched.markdown.utils.text.TypefaceUtils

internal data class StylePatch(
  val paragraphStyle: ParagraphStyle? = null,
  val headingStyles: Map<Int, HeadingStyle>? = null,
  val linkStyle: LinkStyle? = null,
  val strongStyle: StrongStyle? = null,
  val emphasisStyle: EmphasisStyle? = null,
  val superscriptStyle: SuperscriptStyle? = null,
  val subscriptStyle: SubscriptStyle? = null,
  val codeStyle: CodeStyle? = null,
  val codeBlockStyle: CodeBlockStyle? = null,
  val blockquoteStyle: BlockquoteStyle? = null,
  val listStyle: ListStyle? = null,
  val imageStyle: ImageStyle? = null,
  val inlineImageStyle: InlineImageStyle? = null,
  val thematicBreakStyle: ThematicBreakStyle? = null,
)

internal object StyleConfigMerger {
  fun merge(
    resolveContext: StyleResolveContext,
    base: StyleConfig,
    patch: StylePatch,
  ): StyleConfig {
    val headingStyles =
      patch.headingStyles?.let { overrides ->
        base.headingStyles.copyOf().also { styles ->
          overrides.forEach { (level, style) -> styles[level] = style }
        }
      } ?: base.headingStyles

    val headingTypefaces =
      if (patch.headingStyles != null) {
        buildHeadingTypefaces(resolveContext, headingStyles)
      } else {
        base.headingTypefaces
      }

    return StyleConfig(
      paragraphStyleDefault = patch.paragraphStyle ?: base.paragraphStyle,
      headingStyles = headingStyles,
      headingTypefaces = headingTypefaces,
      linkStyle = patch.linkStyle ?: base.linkStyle,
      strongStyle = patch.strongStyle ?: base.strongStyle,
      emphasisStyle = patch.emphasisStyle ?: base.emphasisStyle,
      superscriptStyle = patch.superscriptStyle ?: base.superscriptStyle,
      subscriptStyle = patch.subscriptStyle ?: base.subscriptStyle,
      codeStyle = patch.codeStyle ?: base.codeStyle,
      imageStyle = patch.imageStyle ?: base.imageStyle,
      inlineImageStyle = patch.inlineImageStyle ?: base.inlineImageStyle,
      blockquoteStyle = patch.blockquoteStyle ?: base.blockquoteStyle,
      listStyle = patch.listStyle ?: base.listStyle,
      codeBlockStyle = patch.codeBlockStyle ?: base.codeBlockStyle,
      thematicBreakStyle = patch.thematicBreakStyle ?: base.thematicBreakStyle,
    )
  }

  private fun buildHeadingTypefaces(
    resolveContext: StyleResolveContext,
    headingStyles: Array<HeadingStyle?>,
  ) = Array(headingStyles.size) { level ->
    if (level == 0) {
      null
    } else {
      headingStyles[level]?.let { style ->
        TypefaceUtils.applyStyles(resolveContext.context, style.fontFamily, style.fontWeight)
      }
    }
  }
}
