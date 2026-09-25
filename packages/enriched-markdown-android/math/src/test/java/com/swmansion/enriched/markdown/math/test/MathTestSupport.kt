package com.swmansion.enriched.markdown.math.test

import android.content.Context
import android.text.SpannableStringBuilder
import androidx.test.core.app.ApplicationProvider
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.styles.StyleConfig

/**
 * The slice of core's own test support `:math` needs. Test sources are not published, so a plugin
 * module cannot share `:ui`'s copy.
 */
object MathTestSupport {
  // Resolved per call, not cached: a @Config qualifier is applied to the current test's context,
  // and a singleton would pin the first test's one.
  val context: Context
    get() = ApplicationProvider.getApplicationContext()

  val defaultStyle: StyleConfig get() = StyleConfig.default(context)

  fun render(
    document: MarkdownASTNode,
    style: StyleConfig = defaultStyle,
  ): SpannableStringBuilder {
    val renderer = Renderer()
    renderer.configure(style, context)
    return renderer.renderDocument(document, null, null)
  }

  fun document(vararg children: MarkdownASTNode): MarkdownASTNode = MarkdownASTNode(NodeType.Document, children = children.toList())

  fun paragraph(vararg children: MarkdownASTNode): MarkdownASTNode = MarkdownASTNode(NodeType.Paragraph, children = children.toList())

  fun text(content: String): MarkdownASTNode = MarkdownASTNode(NodeType.Text, content = content)

  fun latexInline(latex: String): MarkdownASTNode = MarkdownASTNode(NodeType.LatexMathInline, children = listOf(text(latex)))

  /** Display math as the parser emits it once promoted out of its paragraph to document level. */
  fun latexDisplay(latex: String): MarkdownASTNode = MarkdownASTNode(NodeType.LatexMathDisplay, children = listOf(text(latex)))
}
