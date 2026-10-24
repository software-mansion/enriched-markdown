package com.swmansion.enriched.markdown.styles

/** Horizontal placement of a table that is narrower than the space available to it. */
enum class TableAlignment {
  /** Follows the reading direction: start-aligned in LTR, end-aligned in RTL. */
  AUTO,
  LEFT,
  CENTER,
  RIGHT,

  /** Opposite the reading direction: end-aligned in LTR, start-aligned in RTL. */
  END,
}
