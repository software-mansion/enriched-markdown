package com.swmansion.enriched.markdown.styles

import android.text.Layout

enum class TextAlignment(
  val needsJustify: Boolean = false,
) {
  /** Follows the reading direction: left-aligned in LTR, right-aligned in RTL. */
  START,
  LEFT,
  CENTER,
  RIGHT,

  /** Opposite the reading direction: right-aligned in LTR, left-aligned in RTL. */
  END,
  JUSTIFY(needsJustify = true),
  AUTO,
  ;

  /**
   * The layout alignment for a paragraph whose direction is [isRtl], or null when the default
   * (start) alignment already applies. Justify is handled at the TextView level.
   */
  fun layoutAlignment(isRtl: Boolean): Layout.Alignment? =
    when (this) {
      START, JUSTIFY, AUTO -> null
      CENTER -> Layout.Alignment.ALIGN_CENTER
      END -> Layout.Alignment.ALIGN_OPPOSITE
      LEFT -> if (isRtl) Layout.Alignment.ALIGN_OPPOSITE else Layout.Alignment.ALIGN_NORMAL
      RIGHT -> if (isRtl) Layout.Alignment.ALIGN_NORMAL else Layout.Alignment.ALIGN_OPPOSITE
    }

  /** Whether the alignment pins a physical side, so it depends on each paragraph's direction. */
  val isAbsolute: Boolean get() = this == LEFT || this == RIGHT
}
