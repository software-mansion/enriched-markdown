package com.swmansion.enriched.markdown.test

import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType

object TestAstFactory {
  fun document(vararg children: MarkdownASTNode): MarkdownASTNode = MarkdownASTNode(NodeType.Document, children = children.toList())

  fun paragraph(vararg children: MarkdownASTNode): MarkdownASTNode = MarkdownASTNode(NodeType.Paragraph, children = children.toList())

  fun text(content: String): MarkdownASTNode = MarkdownASTNode(NodeType.Text, content = content)

  fun strong(vararg children: MarkdownASTNode): MarkdownASTNode = MarkdownASTNode(NodeType.Strong, children = children.toList())

  fun emphasis(vararg children: MarkdownASTNode): MarkdownASTNode = MarkdownASTNode(NodeType.Emphasis, children = children.toList())

  fun link(
    url: String,
    vararg children: MarkdownASTNode,
  ): MarkdownASTNode =
    MarkdownASTNode(
      type = NodeType.Link,
      attributes = mapOf("url" to url),
      children = children.toList(),
    )

  fun heading(
    level: Int,
    vararg children: MarkdownASTNode,
  ): MarkdownASTNode =
    MarkdownASTNode(
      type = NodeType.Heading,
      attributes = mapOf("level" to level.toString()),
      children = children.toList(),
    )

  fun code(content: String): MarkdownASTNode = MarkdownASTNode(NodeType.Code, children = listOf(text(content)))

  fun codeBlock(content: String): MarkdownASTNode = MarkdownASTNode(NodeType.CodeBlock, children = listOf(text(content)))

  fun blockquote(vararg children: MarkdownASTNode): MarkdownASTNode = MarkdownASTNode(NodeType.Blockquote, children = children.toList())

  fun unorderedList(vararg items: MarkdownASTNode): MarkdownASTNode = MarkdownASTNode(NodeType.UnorderedList, children = items.toList())

  fun orderedList(vararg items: MarkdownASTNode): MarkdownASTNode = MarkdownASTNode(NodeType.OrderedList, children = items.toList())

  fun listItem(vararg children: MarkdownASTNode): MarkdownASTNode = MarkdownASTNode(NodeType.ListItem, children = children.toList())

  fun image(
    url: String,
    alt: String = "",
  ): MarkdownASTNode =
    MarkdownASTNode(
      type = NodeType.Image,
      attributes = mapOf("url" to url),
      children = if (alt.isEmpty()) emptyList() else listOf(text(alt)),
    )

  fun thematicBreak(): MarkdownASTNode = MarkdownASTNode(NodeType.ThematicBreak)

  fun softBreak(): MarkdownASTNode = MarkdownASTNode(NodeType.SoftBreak)

  fun lineBreak(): MarkdownASTNode = MarkdownASTNode(NodeType.LineBreak)
}
