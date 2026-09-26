package com.swmansion.enriched.markdown.styles

import com.facebook.react.bridge.ReadableMap

/**
 * Resolved style for a single URL-pattern variant.
 * The `pattern` field is a regex tested against the full URL in normalized order.
 * Fields are pre-merged with the base link style by the JS normalizer — native code
 * uses them directly without any additional fallback logic.
 */
data class LinkVariantEntry(
  val pattern: String,
  val color: Int,
  val underline: Boolean,
  val backgroundColor: Int,
  val fontFamily: String = "",
  val pill: Boolean = false,
  val label: String = "",
  val iconUri: String = "",
  val iconTintColor: Int? = null,
  val borderRadius: Float = 8f,
  val paddingHorizontal: Float = 6f,
  val paddingVertical: Float = 2f,
  val borderWidth: Float = 0f,
  val borderColor: Int = android.graphics.Color.TRANSPARENT,
  val maxWidth: Float = 0f,
) {
  companion object {
    fun fromReadableMap(
      map: ReadableMap,
      parser: StyleParser,
    ): LinkVariantEntry =
      LinkVariantEntry(
        pattern = map.getString("pattern") ?: "",
        color = parser.parseColor(map, "color"),
        underline = parser.parseBoolean(map, "underline"),
        backgroundColor = parser.parseColor(map, "backgroundColor"),
        fontFamily = parser.parseString(map, "fontFamily"),
        pill = parser.parseBoolean(map, "pill"),
        label = parser.parseString(map, "label"),
        iconUri = parser.parseString(map, "iconUri"),
        iconTintColor = parser.parseOptionalColor(map, "iconTintColor"),
        borderRadius = parser.toPixelFromDIP(parser.parseOptionalDouble(map, "borderRadius", 8.0).toFloat()),
        paddingHorizontal = parser.toPixelFromDIP(parser.parseOptionalDouble(map, "paddingHorizontal", 6.0).toFloat()),
        paddingVertical = parser.toPixelFromDIP(parser.parseOptionalDouble(map, "paddingVertical", 2.0).toFloat()),
        borderWidth = parser.toPixelFromDIP(parser.parseOptionalDouble(map, "borderWidth").toFloat()),
        borderColor = parser.parseOptionalColor(map, "borderColor") ?: android.graphics.Color.TRANSPARENT,
        maxWidth = parser.toPixelFromDIP(parser.parseOptionalDouble(map, "maxWidth").toFloat()),
      )
  }
}
