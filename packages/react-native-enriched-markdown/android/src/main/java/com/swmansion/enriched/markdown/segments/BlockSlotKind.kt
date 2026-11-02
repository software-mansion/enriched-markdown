package com.swmansion.enriched.markdown.segments

import com.swmansion.enriched.markdown.styles.StyleConfig

/** The block a React slot child stands in for; it lends the slot its margins. */
enum class BlockSlotKind(
  val attribute: String,
) {
  IMAGE("image"),
  VIDEO("video"),
  LINK("link"),
  ;

  fun marginTop(style: StyleConfig): Int =
    when (this) {
      IMAGE -> style.imageStyle.marginTop.toInt()
      VIDEO -> style.videoStyle.marginTop.toInt()
      LINK -> style.paragraphStyle.marginTop.toInt()
    }

  fun marginBottom(style: StyleConfig): Int =
    when (this) {
      IMAGE -> style.imageStyle.marginBottom.toInt()
      VIDEO -> style.videoStyle.marginBottom.toInt()
      LINK -> style.paragraphStyle.marginBottom.toInt()
    }

  companion object {
    /** The `blockSlotKind` attribute the core stamps (BlockSlots.hpp); anything else is an image. */
    fun fromAttribute(value: String?): BlockSlotKind = entries.firstOrNull { it.attribute == value } ?: IMAGE
  }
}
