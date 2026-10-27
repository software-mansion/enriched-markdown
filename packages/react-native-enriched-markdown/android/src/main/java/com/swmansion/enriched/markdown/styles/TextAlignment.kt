package com.swmansion.enriched.markdown.styles

import android.text.Layout

enum class TextAlignment(
  val needsJustify: Boolean = false,
) {
  LEFT,
  CENTER,
  RIGHT,
  JUSTIFY(needsJustify = true),

  /** Follows the reading direction: left-aligned in LTR, right-aligned in RTL. */
  AUTO,
  ;

  /**
   * The layout alignment for a paragraph whose direction is [isRtl], or null when the default
   * (start) alignment already applies. Justify is handled at the TextView level.
   */
  fun layoutAlignment(isRtl: Boolean): Layout.Alignment? =
    when (this) {
      JUSTIFY, AUTO -> null
      CENTER -> Layout.Alignment.ALIGN_CENTER
      LEFT -> if (isRtl) Layout.Alignment.ALIGN_OPPOSITE else Layout.Alignment.ALIGN_NORMAL
      RIGHT -> if (isRtl) Layout.Alignment.ALIGN_NORMAL else Layout.Alignment.ALIGN_OPPOSITE
    }

  /** Whether the alignment pins a physical side, so it depends on each paragraph's direction. */
  val isAbsolute: Boolean get() = this == LEFT || this == RIGHT

  companion object {
    fun fromString(value: String): TextAlignment =
      when (value.lowercase()) {
        "center" -> CENTER
        "right" -> RIGHT
        "justify" -> JUSTIFY
        "auto" -> AUTO
        else -> LEFT
      }
  }
}
