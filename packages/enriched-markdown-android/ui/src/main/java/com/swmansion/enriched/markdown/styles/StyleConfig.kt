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
  val superscriptStyle: SuperscriptStyle = SuperscriptStyle(),
  val subscriptStyle: SubscriptStyle = SubscriptStyle(),
  val codeStyle: CodeStyle,
  val imageStyle: ImageStyle,
  val inlineImageStyle: InlineImageStyle,
  val blockquoteStyle: BlockquoteStyle,
  val listStyle: ListStyle,
  val taskListStyle: TaskListStyle,
  val codeBlockStyle: CodeBlockStyle,
  val thematicBreakStyle: ThematicBreakStyle,
  val tableStyle: TableStyle,
  val tableTypeface: Typeface? = null,
  val tableHeaderTypeface: Typeface? = null,
  /** Styles owned by plugins, keyed by the [StyleExtensionKey] each plugin declares. */
  val extensions: Map<StyleExtensionKey<*>, Any> = emptyMap(),
  val spoilerStyle: SpoilerStyle = SpoilerStyle(),
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

  fun tableCellParagraphStyle(isHeader: Boolean): ParagraphStyle =
    paragraphStyleDefault.copy(
      fontSize = tableStyle.fontSize,
      fontFamily =
        if (isHeader && tableStyle.headerFontFamily.isNotEmpty()) {
          tableStyle.headerFontFamily
        } else {
          tableStyle.fontFamily
        },
      fontWeight = if (isHeader) "bold" else tableStyle.fontWeight,
      color = if (isHeader) tableStyle.headerTextColor else tableStyle.color,
      lineHeight = tableStyle.lineHeight,
      marginTop = 0f,
      marginBottom = 0f,
      textAlign = TextAlignment.AUTO,
    )

  /** The value stored for [key], or null when no plugin supplied one. */
  @Suppress("UNCHECKED_CAST")
  operator fun <T : Any> get(key: StyleExtensionKey<T>): T? = extensions[key] as T?

  fun <T : Any> getOrDefault(
    key: StyleExtensionKey<T>,
    default: T,
  ): T = get(key) ?: default

  /** A copy carrying [value] under [key]; [StyleConfig] is shared across views, so it is never mutated in place. */
  fun <T : Any> withExtension(
    key: StyleExtensionKey<T>,
    value: T,
  ): StyleConfig =
    StyleConfig(
      paragraphStyleDefault = paragraphStyleDefault,
      headingStyles = headingStyles,
      headingTypefaces = headingTypefaces,
      linkStyle = linkStyle,
      strongStyle = strongStyle,
      emphasisStyle = emphasisStyle,
      strikethroughStyle = strikethroughStyle,
      underlineStyle = underlineStyle,
      superscriptStyle = superscriptStyle,
      subscriptStyle = subscriptStyle,
      codeStyle = codeStyle,
      imageStyle = imageStyle,
      inlineImageStyle = inlineImageStyle,
      blockquoteStyle = blockquoteStyle,
      listStyle = listStyle,
      taskListStyle = taskListStyle,
      codeBlockStyle = codeBlockStyle,
      thematicBreakStyle = thematicBreakStyle,
      tableStyle = tableStyle,
      tableTypeface = tableTypeface,
      tableHeaderTypeface = tableHeaderTypeface,
      extensions = extensions + (key to value),
    )

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
      superscriptStyle == other.superscriptStyle &&
      subscriptStyle == other.subscriptStyle &&
      codeStyle == other.codeStyle &&
      imageStyle == other.imageStyle &&
      inlineImageStyle == other.inlineImageStyle &&
      blockquoteStyle == other.blockquoteStyle &&
      listStyle == other.listStyle &&
      taskListStyle == other.taskListStyle &&
      codeBlockStyle == other.codeBlockStyle &&
      thematicBreakStyle == other.thematicBreakStyle &&
      tableStyle == other.tableStyle &&
      extensions == other.extensions &&
      spoilerStyle == other.spoilerStyle
  }

  override fun hashCode(): Int {
    var result = paragraphStyleDefault.hashCode()
    result = 31 * result + headingStyles.contentHashCode()
    result = 31 * result + linkStyle.hashCode()
    result = 31 * result + strongStyle.hashCode()
    result = 31 * result + emphasisStyle.hashCode()
    result = 31 * result + strikethroughStyle.hashCode()
    result = 31 * result + underlineStyle.hashCode()
    result = 31 * result + superscriptStyle.hashCode()
    result = 31 * result + subscriptStyle.hashCode()
    result = 31 * result + codeStyle.hashCode()
    result = 31 * result + imageStyle.hashCode()
    result = 31 * result + inlineImageStyle.hashCode()
    result = 31 * result + blockquoteStyle.hashCode()
    result = 31 * result + listStyle.hashCode()
    result = 31 * result + taskListStyle.hashCode()
    result = 31 * result + codeBlockStyle.hashCode()
    result = 31 * result + thematicBreakStyle.hashCode()
    result = 31 * result + tableStyle.hashCode()
    result = 31 * result + extensions.hashCode()
    result = 31 * result + spoilerStyle.hashCode()
    return result
  }

  companion object {
    fun default(context: Context): StyleConfig = DefaultStyles.create(context)
  }
}
