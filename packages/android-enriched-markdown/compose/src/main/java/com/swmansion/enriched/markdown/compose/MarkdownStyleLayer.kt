package com.swmansion.enriched.markdown.compose

import androidx.compose.runtime.Immutable
import com.swmansion.enriched.markdown.compose.style.StyleConfigMerger
import com.swmansion.enriched.markdown.compose.style.StylePatch
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.compose.style.StyleUnits
import com.swmansion.enriched.markdown.styles.StyleConfig

@Immutable
internal data class MarkdownStyleLayer(
  val paragraph: TextStylePatch? = null,
  val headingPatches: Map<Int, TextStylePatch> = emptyMap(),
  val link: LinkStylePatch? = null,
  val strong: StrongStylePatch? = null,
  val emphasis: EmphasisStylePatch? = null,
  val strikethrough: StrikethroughStylePatch? = null,
  val underline: UnderlineStylePatch? = null,
  val code: CodeStylePatch? = null,
  val codeBlock: CodeBlockStylePatch? = null,
  val blockquote: BlockquoteStylePatch? = null,
  val list: ListStylePatch? = null,
  val image: ImageStylePatch? = null,
  val inlineImage: InlineImageStylePatch? = null,
  val thematicBreak: ThematicBreakStylePatch? = null,
) {
  fun apply(
    resolveContext: StyleResolveContext,
    base: StyleConfig,
  ): StyleConfig {
    val units = StyleUnits(resolveContext.density)
    val headingStyles =
      headingPatches
        .mapNotNull { (level, patch) ->
          base.headingStyles.getOrNull(level)?.let { level to patch.apply(it, resolveContext, units) }
        }.toMap()
        .takeIf { it.isNotEmpty() }

    return StyleConfigMerger.merge(
      resolveContext = resolveContext,
      base = base,
      patch =
        StylePatch(
          paragraphStyle = paragraph?.apply(base.paragraphStyle, resolveContext, units),
          headingStyles = headingStyles,
          linkStyle = link?.apply(base.linkStyle, resolveContext, units),
          strongStyle = strong?.apply(base.strongStyle, resolveContext, units),
          emphasisStyle = emphasis?.apply(base.emphasisStyle, resolveContext, units),
          strikethroughStyle = strikethrough?.apply(base.strikethroughStyle, units),
          underlineStyle = underline?.apply(base.underlineStyle, units),
          codeStyle = code?.apply(base.codeStyle, resolveContext, units),
          codeBlockStyle = codeBlock?.apply(base.codeBlockStyle, resolveContext, units),
          blockquoteStyle = blockquote?.apply(base.blockquoteStyle, resolveContext, units),
          listStyle = list?.apply(base.listStyle, resolveContext, units),
          imageStyle = image?.apply(base.imageStyle, units),
          inlineImageStyle = inlineImage?.apply(base.inlineImageStyle, units),
          thematicBreakStyle = thematicBreak?.apply(base.thematicBreakStyle, units),
        ),
    )
  }
}
