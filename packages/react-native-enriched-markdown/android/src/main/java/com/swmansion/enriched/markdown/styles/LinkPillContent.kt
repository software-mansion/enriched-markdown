package com.swmansion.enriched.markdown.styles

import com.facebook.react.bridge.ReadableMap

/**
 * What a pill shows: the variant's default, or one specific link's override keyed by
 * exact URL in the `linkPillContent` prop. Empty strings mean "not set".
 */
data class LinkPillContent(
  val label: String = "",
  val iconUri: String = "",
) {
  /** Fields unset here take their value from [fallback]. */
  fun orElse(fallback: LinkPillContent) =
    LinkPillContent(
      label = label.ifEmpty { fallback.label },
      iconUri = iconUri.ifEmpty { fallback.iconUri },
    )

  companion object {
    fun fromReadableMap(map: ReadableMap) = LinkPillContent(map.getString("label") ?: "", map.getString("iconUri") ?: "")
  }
}
