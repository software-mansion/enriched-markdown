package com.swmansion.enriched.markdown.spans

/**
 * Typed formatting markers for the actual MarkdownExtractor's span queries.
 * These do not model Android drawing; they supply the read-only metadata that
 * extraction consumes. Link marker fields match production LinkSpan's contract.
 */
class LinkSpan(
  val url: String,
  val recognizedLink: Boolean = false,
)

class CodeSpan

class StrongSpan

class EmphasisSpan

class StrikethroughSpan

class HighlightSpan

class CodeBlockSpan

class ThematicBreakSpan

class HeadingSpan(
  val level: Int,
)

class BlockquoteSpan(
  val depth: Int,
)

class ImageSpan(
  val imageUrl: String,
  val isInline: Boolean,
)

class BaselineShiftSpan(
  val spanType: SpanType,
) {
  enum class SpanType { SUPERSCRIPT, SUBSCRIPT }
}

open class BaseListSpan(
  val depth: Int,
)

class UnorderedListSpan(
  depth: Int,
) : BaseListSpan(depth)

class OrderedListSpan(
  depth: Int,
  val itemNumber: Int,
) : BaseListSpan(depth)

class TaskListSpan(
  depth: Int,
  val isChecked: Boolean,
) : BaseListSpan(depth)
