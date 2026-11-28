package com.swmansion.enriched.markdown.styles

import android.graphics.ColorFilter
import android.graphics.PorterDuff
import android.graphics.PorterDuffColorFilter
import com.facebook.react.bridge.ReadableMap

/** An icon drawn before a link's own text, which stays text and wraps. */
data class LinkInlineIconStyle(
  val iconUri: String,
  val iconTintColor: Int? = null,
) {
  /** Replaces the icon's colors and keeps its alpha. */
  val iconTint: ColorFilter? = iconTintColor?.let { PorterDuffColorFilter(it, PorterDuff.Mode.SRC_IN) }

  companion object {
    /** Returns null when the variant shows no inline icon. */
    fun fromReadableMap(
      map: ReadableMap,
      parser: StyleParser,
    ): LinkInlineIconStyle? {
      val iconUri = map.getString("iconUri").orEmpty()
      if (iconUri.isEmpty()) return null
      return LinkInlineIconStyle(iconUri, parser.parseOptionalColor(map, "iconTintColor"))
    }
  }
}
