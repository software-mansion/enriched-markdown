package com.swmansion.enriched.markdown.parser

fun MarkdownASTNode.firstOfType(type: MarkdownASTNode.NodeType): MarkdownASTNode? {
  if (this.type == type) {
    return this
  }
  for (child in children) {
    val match = child.firstOfType(type)
    if (match != null) {
      return match
    }
  }
  return null
}

fun MarkdownASTNode.allOfType(type: MarkdownASTNode.NodeType): List<MarkdownASTNode> {
  val result = mutableListOf<MarkdownASTNode>()
  collectNodesOfType(type, result)
  return result
}

private fun MarkdownASTNode.collectNodesOfType(
  type: MarkdownASTNode.NodeType,
  result: MutableList<MarkdownASTNode>,
) {
  if (this.type == type) {
    result.add(this)
  }
  for (child in children) {
    child.collectNodesOfType(type, result)
  }
}

fun MarkdownASTNode.assertHasChildType(type: MarkdownASTNode.NodeType): MarkdownASTNode {
  val child =
    children.firstOrNull { it.type == type }
      ?: throw AssertionError("Expected child of type $type in $this")
  return child
}
