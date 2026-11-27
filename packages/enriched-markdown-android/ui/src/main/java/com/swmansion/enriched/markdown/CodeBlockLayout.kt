package com.swmansion.enriched.markdown

/** How a fenced code block fits lines wider than the view. */
enum class CodeBlockLayout {
  /** Lines wrap, and the code is part of the text selection. */
  Wrapping,

  /**
   * Lines keep their length and scroll horizontally inside the block. Applies to code blocks at
   * the top level of the document: each is a view of its own, outside the text selection, and a
   * long-press copies it. A code block inside a list item or a quote still wraps.
   */
  Scrollable,
}
