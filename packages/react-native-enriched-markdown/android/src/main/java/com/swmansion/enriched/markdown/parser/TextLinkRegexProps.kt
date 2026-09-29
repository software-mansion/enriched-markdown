package com.swmansion.enriched.markdown.parser

import com.facebook.react.bridge.ReadableMap
import com.swmansion.enriched.markdown.input.autolink.LinkRegexConfig

internal fun parseTextLinkRegex(map: ReadableMap?): LinkRegexConfig? {
  if (map == null) return null
  return LinkRegexConfig(
    pattern = if (map.hasKey("pattern")) map.getString("pattern") ?: "" else "",
    caseInsensitive = map.hasKey("caseInsensitive") && map.getBoolean("caseInsensitive"),
    dotAll = map.hasKey("dotAll") && map.getBoolean("dotAll"),
    isDisabled = !map.hasKey("isDisabled") || map.getBoolean("isDisabled"),
    isDefault = map.hasKey("isDefault") && map.getBoolean("isDefault"),
  )
}
