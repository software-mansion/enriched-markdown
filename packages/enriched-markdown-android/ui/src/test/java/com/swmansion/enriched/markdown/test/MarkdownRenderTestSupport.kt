package com.swmansion.enriched.markdown.test

import android.content.Context
import android.text.Spannable
import androidx.test.core.app.ApplicationProvider
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.styles.BlockquoteStyle
import com.swmansion.enriched.markdown.styles.CodeStyle
import com.swmansion.enriched.markdown.styles.HeadingStyle
import com.swmansion.enriched.markdown.styles.LinkStyle
import com.swmansion.enriched.markdown.styles.ParagraphStyle
import com.swmansion.enriched.markdown.styles.SpoilerStyle
import com.swmansion.enriched.markdown.styles.StrikethroughStyle
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.TaskListStyle
import com.swmansion.enriched.markdown.styles.TextAlignment
import com.swmansion.enriched.markdown.styles.UnderlineStyle

object MarkdownRenderTestSupport {
  // Resolved per call, not cached: a @Config qualifier (a locale, an RTL layout direction) is
  // applied to the current test's context, and a singleton would pin the first test's one.
  private val context: Context
    get() = ApplicationProvider.getApplicationContext()

  val defaultStyle: StyleConfig get() = StyleConfig.default(context)

  fun render(
    document: MarkdownASTNode,
    style: StyleConfig = defaultStyle,
  ): Spannable {
    val renderer = Renderer()
    renderer.configure(style, context)
    return renderer.renderDocument(document, null, null)
  }

  /** [defaultStyle] with only the inline line-decoration colors replaced. */
  fun styleWithDecorationColors(
    strikethroughColor: Int? = null,
    underlineColor: Int? = null,
  ): StyleConfig =
    copyOfDefault(
      strikethroughStyle = StrikethroughStyle(color = strikethroughColor),
      underlineStyle = UnderlineStyle(color = underlineColor),
    )

  /** [defaultStyle] with only its [BlockquoteStyle] replaced. */
  fun styleWithBlockquote(blockquoteStyle: BlockquoteStyle): StyleConfig = copyOfDefault(blockquoteStyle = blockquoteStyle)

  /** [defaultStyle] with only its inline [CodeStyle] replaced. */
  fun styleWithCode(codeStyle: CodeStyle): StyleConfig = copyOfDefault(codeStyle = codeStyle)

  /** [defaultStyle] with only its [SpoilerStyle] replaced. */
  fun styleWithSpoiler(spoilerStyle: SpoilerStyle): StyleConfig = copyOfDefault(spoilerStyle = spoilerStyle)

  /** [defaultStyle] with only its [LinkStyle] replaced. */
  fun styleWithLink(linkStyle: LinkStyle): StyleConfig = copyOfDefault(linkStyle = linkStyle)

  /** [defaultStyle] with paragraphs and every heading aligned by [textAlign]. */
  fun styleWithTextAlign(textAlign: TextAlignment): StyleConfig {
    val base = defaultStyle
    return copyOfDefault(
      paragraphStyle = base.paragraphStyle.copy(textAlign = textAlign),
      headingStyles = base.headingStyles.map { it?.copy(textAlign = textAlign) }.toTypedArray(),
    )
  }

  /** [defaultStyle] with only its [TaskListStyle] replaced. */
  fun styleWithTaskList(taskListStyle: TaskListStyle): StyleConfig = copyOfDefault(taskListStyle = taskListStyle)

  fun defaultTaskListStyle(): TaskListStyle = defaultStyle.taskListStyle

  /** [StyleConfig] has no `copy`, so rebuild it field by field from [defaultStyle]. */
  private fun copyOfDefault(
    strikethroughStyle: StrikethroughStyle? = null,
    underlineStyle: UnderlineStyle? = null,
    taskListStyle: TaskListStyle? = null,
    blockquoteStyle: BlockquoteStyle? = null,
    codeStyle: CodeStyle? = null,
    spoilerStyle: SpoilerStyle? = null,
    linkStyle: LinkStyle? = null,
    paragraphStyle: ParagraphStyle? = null,
    headingStyles: Array<HeadingStyle?>? = null,
  ): StyleConfig {
    val base = defaultStyle
    return StyleConfig(
      paragraphStyleDefault = paragraphStyle ?: base.paragraphStyle,
      headingStyles = headingStyles ?: base.headingStyles,
      headingTypefaces = base.headingTypefaces,
      linkStyle = linkStyle ?: base.linkStyle,
      strongStyle = base.strongStyle,
      emphasisStyle = base.emphasisStyle,
      strikethroughStyle = strikethroughStyle ?: base.strikethroughStyle,
      underlineStyle = underlineStyle ?: base.underlineStyle,
      superscriptStyle = base.superscriptStyle,
      subscriptStyle = base.subscriptStyle,
      codeStyle = codeStyle ?: base.codeStyle,
      imageStyle = base.imageStyle,
      inlineImageStyle = base.inlineImageStyle,
      blockquoteStyle = blockquoteStyle ?: base.blockquoteStyle,
      listStyle = base.listStyle,
      taskListStyle = taskListStyle ?: base.taskListStyle,
      codeBlockStyle = base.codeBlockStyle,
      thematicBreakStyle = base.thematicBreakStyle,
      tableStyle = base.tableStyle,
      tableTypeface = base.tableTypeface,
      tableHeaderTypeface = base.tableHeaderTypeface,
      spoilerStyle = spoilerStyle ?: base.spoilerStyle,
    )
  }
}
