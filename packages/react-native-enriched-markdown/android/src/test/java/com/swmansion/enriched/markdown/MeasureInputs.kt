package com.swmansion.enriched.markdown

import com.facebook.react.bridge.ReadableMap
import com.swmansion.enriched.markdown.utils.common.getStringOrDefault

// The streaming options that lay a document out, as conversions.h's streamingLayoutConfig sends.
private val STREAMING_LAYOUT_KEYS = setOf("tableMode", "codeBlockMode", "mediaMode", "smooth")

/**
 * A measurement's inputs from a props map that carries the markdown and the layout props, keyed by
 * what conversions.h would send, as the shadow node would key them. Hashed as plain maps, since a
 * native array inside (the style's `linkVariants`) hashes by identity.
 */
internal fun measureInputOf(props: ReadableMap?): MeasureInput {
  val layout =
    props?.toHashMap()?.apply {
      remove("markdown")
      val streamingConfig = get("streamingConfig").let { (it as? ReadableMap)?.toHashMap() ?: it as? Map<*, *> }
      streamingConfig?.let { put("streamingConfig", it.filterKeys { key -> key in STREAMING_LAYOUT_KEYS }) }
    }
  return MeasureInput(props.getStringOrDefault("markdown", ""), MeasureConfig(layout?.hashCode() ?: 0, props))
}
