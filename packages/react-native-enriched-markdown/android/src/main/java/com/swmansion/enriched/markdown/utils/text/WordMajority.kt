package com.swmansion.enriched.markdown.utils.text

import android.text.SpannableStringBuilder
import android.text.Spanned
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.parser.isTopLevelBlock
import com.swmansion.enriched.markdown.styles.StyleConfig

/** AST attribute holding a block's resolved prose direction ("ltr" / "rtl"). */
internal const val PROSE_DIRECTION = "_enrmProseDirection"

const val WRITING_DIRECTION_WORD_MAJORITY = "word-majority"

/** Marks bidi controls the renderer inserted, so copy can drop them again. */
class DirectionControlSpan

private fun isRtlLetter(c: Int): Boolean =
  c in 0x0590..0x08FF || c in 0xFB1D..0xFDFF || c in 0xFE70..0xFEFF || c in 0x10800..0x10FFF || c in 0x1E800..0x1EFFF

/** Direction of most words in [text]; each word votes by its first letter, a tie goes to the first word. */
internal fun wordMajorityDirection(text: String): String? {
  var rtl = 0
  var ltr = 0
  var first: String? = null
  var counted = false
  var offset = 0
  while (offset < text.length) {
    val c = text.codePointAt(offset)
    offset += Character.charCount(c)
    if (Character.isWhitespace(c) || Character.isSpaceChar(c)) {
      counted = false
    } else if (!counted && Character.isLetter(c)) {
      val direction = if (isRtlLetter(c)) "rtl" else "ltr"
      if (first == null) first = direction
      if (direction == "rtl") rtl++ else ltr++
      counted = true
    }
  }
  return if (rtl == ltr) {
    first
  } else if (rtl > ltr) {
    "rtl"
  } else {
    "ltr"
  }
}

private fun collectProse(
  node: MarkdownASTNode,
  text: StringBuilder,
  isPill: (String) -> Boolean,
) {
  when (node.type) {
    NodeType.Code, NodeType.CodeBlock, NodeType.Table, NodeType.Image, NodeType.Video,
    NodeType.LatexMathInline, NodeType.LatexMathDisplay,
    -> {
      text.append(' ')
      return
    }

    // ponytail: a pill link never votes, even when the renderer falls back to plain text for it.
    NodeType.Link -> {
      if (isPill(node.attributes["url"] ?: "")) {
        text.append(' ')
        return
      }
    }

    NodeType.Text -> {
      text.append(node.content)
      return
    }

    else -> {}
  }
  // Separate blocks and line breaks so words on either side don't merge.
  text.append(' ')
  node.children.forEach { collectProse(it, text, isPill) }
}

private fun withWordMajority(
  node: MarkdownASTNode,
  inherited: String?,
  isPill: (String) -> Boolean,
): MarkdownASTNode {
  // Column order stays LTR; each table cell resolves on its own. The table's own mark only
  // tells TableContainerView the mode is on.
  if (node.type in CONTAINERS) {
    return node.copy(
      attributes = if (node.type == NodeType.Table) node.attributes + (PROSE_DIRECTION to "ltr") else node.attributes,
      children = node.children.map { withWordMajority(it, null, isPill) },
    )
  }
  val direction = inherited ?: wordMajorityDirection(buildString { collectProse(node, this, isPill) }) ?: "ltr"
  val annotated =
    node.type.isTopLevelBlock() || node.type == NodeType.ListItem || node.type == NodeType.Code ||
      node.type == NodeType.TableCell || node.type == NodeType.TableHeaderCell
  if (!annotated && node.children.isEmpty()) return node
  return node.copy(
    attributes = if (annotated) node.attributes + (PROSE_DIRECTION to direction) else node.attributes,
    children = node.children.map { withWordMajority(it, direction, isPill) },
  )
}

private val CONTAINERS = setOf(NodeType.Document, NodeType.Table, NodeType.TableHead, NodeType.TableBody, NodeType.TableRow)

/**
 * writingDirection="word-majority": a copy of [ast] with [PROSE_DIRECTION] on every block, list
 * item, inline code span and table cell. Lists and quotes share one direction; inline code and
 * link pills don't vote. Returns [ast] unchanged for any other mode.
 */
internal fun wordMajorityAST(
  ast: MarkdownASTNode,
  style: StyleConfig,
  writingDirection: String?,
): MarkdownASTNode {
  if (writingDirection != WRITING_DIRECTION_WORD_MAJORITY) return ast
  // Same first-match rule as SpanStyleCache's variant lookup.
  val variants = style.linkVariants.mapNotNull { entry -> runCatching { Regex(entry.pattern) to entry }.getOrNull() }
  return withWordMajority(ast, null) { url -> variants.firstOrNull { it.first.containsMatchIn(url) }?.second?.pill != null }
}

/** [text] without the bidi controls the renderer inserted; authored marks stay. */
internal fun withoutDirectionControls(text: CharSequence): CharSequence {
  if (text !is Spanned) return text
  val controls = text.getSpans(0, text.length, DirectionControlSpan::class.java)
  if (controls.isEmpty()) return text
  val clean = SpannableStringBuilder(text)
  controls.sortedByDescending { clean.getSpanStart(it) }.forEach {
    val start = clean.getSpanStart(it)
    val end = clean.getSpanEnd(it)
    clean.removeSpan(it)
    if (start in 0 until end) clean.delete(start, end)
  }
  return clean
}
