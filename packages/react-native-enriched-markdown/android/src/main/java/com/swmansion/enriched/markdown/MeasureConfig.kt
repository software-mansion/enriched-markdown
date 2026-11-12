package com.swmansion.enriched.markdown

import com.facebook.react.bridge.ReadableMap
import com.swmansion.enriched.markdown.parser.Md4cFlags
import com.swmansion.enriched.markdown.utils.common.getArrayOrNull
import com.swmansion.enriched.markdown.utils.common.getBooleanOrDefault
import com.swmansion.enriched.markdown.utils.common.getMapOrNull
import com.swmansion.enriched.markdown.utils.common.getStringOrDefault
import com.swmansion.enriched.markdown.utils.common.parseImageRequestHeaders
import com.swmansion.enriched.markdown.utils.common.parseImageSources
import com.swmansion.enriched.markdown.utils.common.parseLinkPillContent
import com.swmansion.enriched.markdown.utils.common.parseLinkRecognition
import com.swmansion.enriched.markdown.utils.common.parseMd4cFlags

/**
 * Everything besides the markdown that lays a document out: the layout props (conversions.h),
 * parsed once. The shadow node interns each config by value and measures with its [key], so the
 * same key is the same config.
 */
internal class MeasureConfig(
  val key: Int,
  map: ReadableMap?,
) {
  val markdownStyle: ReadableMap? = map.getMapOrNull("markdownStyle")
  val md4cFlags: Md4cFlags = parseMd4cFlags(map.getMapOrNull("md4cFlags"))
  val linkRecognition = parseLinkRecognition(map.getMapOrNull("linkRecognition"))
  val imageRequestHeaders = parseImageRequestHeaders(map.getArrayOrNull("imageRequestHeaders"))
  val imageSources = parseImageSources(map.getArrayOrNull("imageSources"))
  val linkPillContent = parseLinkPillContent(map.getArrayOrNull("linkPillContent"))
  val allowTrailingMargin = map.getBooleanOrDefault("allowTrailingMargin", false)
  val enableCodeBlockWrapToggle = map.getBooleanOrDefault("enableCodeBlockWrapToggle", true)
  val streaming = map.getBooleanOrDefault("streaming", false)

  val isGFM = map.getBooleanOrDefault("isGFM", false)

  // Absent ones leave the view's own value in place (MeasurementStore keeps them per view); only
  // EnrichedMarkdownText has a line clamp.
  val allowFontScaling: Boolean? = map?.takeIf { it.hasKey("allowFontScaling") }?.getBoolean("allowFontScaling")
  val maxFontSizeMultiplier: Float? = map?.takeIf { it.hasKey("maxFontSizeMultiplier") }?.getDouble("maxFontSizeMultiplier")?.toFloat()
  val numberOfLines: Int? = map?.takeIf { it.hasKey("numberOfLines") }?.getDouble("numberOfLines")?.toInt()
  val ellipsizeMode: String? = map?.takeIf { it.hasKey("ellipsizeMode") }?.getString("ellipsizeMode")
  val textBreakStrategy: String? = map?.takeIf { it.hasKey("textBreakStrategy") }?.getString("textBreakStrategy")

  private val streamingConfig = map.getMapOrNull("streamingConfig")
  val tableMode = streamingConfig.getStringOrDefault("tableMode", "")
  val codeBlockMode = streamingConfig.getStringOrDefault("codeBlockMode", "")
  val mediaMode = streamingConfig.getStringOrDefault("mediaMode", "")
  val smooth = streamingConfig.getBooleanOrDefault("smooth", false)
}

/** One measurement's inputs: the markdown and its layout config. */
internal class MeasureInput(
  val markdown: String,
  val config: MeasureConfig,
)
