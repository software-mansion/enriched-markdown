package com.swmansion.enriched.markdown.styles

import android.content.Context
import android.graphics.Typeface

class StyleConfig(
  paragraphStyleDefault: ParagraphStyle,
  val headingStyles: Array<HeadingStyle?>,
  val headingTypefaces: Array<Typeface?>,
  val linkStyle: LinkStyle,
  val strongStyle: StrongStyle,
  val emphasisStyle: EmphasisStyle,
  val strikethroughStyle: StrikethroughStyle = StrikethroughStyle(),
  val underlineStyle: UnderlineStyle = UnderlineStyle(),
  val codeStyle: CodeStyle,
  val imageStyle: ImageStyle,
  val inlineImageStyle: InlineImageStyle,
  val blockquoteStyle: BlockquoteStyle,
  val listStyle: ListStyle,
  val codeBlockStyle: CodeBlockStyle,
  val thematicBreakStyle: ThematicBreakStyle,
) {
  private val paragraphStyleDefault: ParagraphStyle = paragraphStyleDefault
  private var paragraphStyleOverride: ParagraphStyle? = null

  val paragraphStyle: ParagraphStyle
    get() = paragraphStyleOverride ?: paragraphStyleDefault

  fun <T> withParagraphOverride(
    override: ParagraphStyle,
    block: () -> T,
  ): T {
    paragraphStyleOverride = override
    try {
      return block()
    } finally {
      paragraphStyleOverride = null
    }
  }

  val needsJustify: Boolean
    get() =
      paragraphStyle.textAlign.needsJustify ||
        headingStyles.filterNotNull().any { it.textAlign.needsJustify }

  override fun equals(other: Any?): Boolean {
    if (this === other) return true
    if (other !is StyleConfig) return false
    return paragraphStyleDefault == other.paragraphStyleDefault &&
      headingStyles.contentEquals(other.headingStyles) &&
      linkStyle == other.linkStyle &&
      strongStyle == other.strongStyle &&
      emphasisStyle == other.emphasisStyle &&
      strikethroughStyle == other.strikethroughStyle &&
      underlineStyle == other.underlineStyle &&
      codeStyle == other.codeStyle &&
      imageStyle == other.imageStyle &&
      inlineImageStyle == other.inlineImageStyle &&
      blockquoteStyle == other.blockquoteStyle &&
      listStyle == other.listStyle &&
      codeBlockStyle == other.codeBlockStyle &&
      thematicBreakStyle == other.thematicBreakStyle
  }

  override fun hashCode(): Int {
    var result = paragraphStyleDefault.hashCode()
    result = 31 * result + headingStyles.contentHashCode()
    result = 31 * result + linkStyle.hashCode()
    result = 31 * result + strongStyle.hashCode()
    result = 31 * result + emphasisStyle.hashCode()
    result = 31 * result + strikethroughStyle.hashCode()
    result = 31 * result + underlineStyle.hashCode()
    result = 31 * result + codeStyle.hashCode()
    result = 31 * result + imageStyle.hashCode()
    result = 31 * result + inlineImageStyle.hashCode()
    result = 31 * result + blockquoteStyle.hashCode()
    result = 31 * result + listStyle.hashCode()
    result = 31 * result + codeBlockStyle.hashCode()
    result = 31 * result + thematicBreakStyle.hashCode()
    return result
  }

  companion object {
    fun default(context: Context): StyleConfig = DefaultStyles.create(context)
  }
}
