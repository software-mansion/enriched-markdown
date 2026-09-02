package com.swmansion.enriched.markdown.test

import android.content.Context
import android.text.SpannableString
import androidx.test.core.app.ApplicationProvider
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.TaskListStyle

object MarkdownRenderTestSupport {
  private val context: Context = ApplicationProvider.getApplicationContext()

  fun render(document: MarkdownASTNode): SpannableString = render(document, StyleConfig.default(context))

  fun render(
    document: MarkdownASTNode,
    style: StyleConfig,
  ): SpannableString {
    val renderer = Renderer()
    renderer.configure(style, context)
    return renderer.renderDocument(document, null, null)
  }

  /** The default style with only its [TaskListStyle] replaced — [StyleConfig] has no `copy`. */
  fun styleWithTaskList(taskListStyle: TaskListStyle): StyleConfig {
    val base = StyleConfig.default(context)
    return StyleConfig(
      paragraphStyleDefault = base.paragraphStyle,
      headingStyles = base.headingStyles,
      headingTypefaces = base.headingTypefaces,
      linkStyle = base.linkStyle,
      strongStyle = base.strongStyle,
      emphasisStyle = base.emphasisStyle,
      codeStyle = base.codeStyle,
      imageStyle = base.imageStyle,
      inlineImageStyle = base.inlineImageStyle,
      blockquoteStyle = base.blockquoteStyle,
      listStyle = base.listStyle,
      taskListStyle = taskListStyle,
      codeBlockStyle = base.codeBlockStyle,
      thematicBreakStyle = base.thematicBreakStyle,
    )
  }

  fun defaultTaskListStyle(): TaskListStyle = StyleConfig.default(context).taskListStyle
}
