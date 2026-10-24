package com.swmansion.enriched.markdown.benchmark

import android.content.Context
import com.facebook.react.bridge.JavaOnlyArray
import com.facebook.react.bridge.JavaOnlyMap
import com.facebook.react.bridge.ReadableMap
import org.json.JSONArray
import org.json.JSONObject

/**
 * The `markdownStyle` map an Android `<EnrichedMarkdownText>` receives from JS when the
 * app passes none, read from `default_style.json`.
 *
 * That file is generated from the library's own `normalizeMarkdownStyle` by
 * `tools/generate-default-style.mjs`; regenerate it rather than editing it by hand.
 * Numbers become doubles, as they do when JS props cross into a `ReadableMap`.
 */
object DefaultMarkdownStyle {
  private const val ASSET = "default_style.json"

  fun load(testContext: Context): ReadableMap {
    val json =
      testContext.assets
        .open(ASSET)
        .bufferedReader()
        .use { it.readText() }
    return JSONObject(json).toReadableMap()
  }

  private fun JSONObject.toReadableMap(): JavaOnlyMap {
    val map = JavaOnlyMap()
    for (key in keys()) {
      when (val value = get(key)) {
        is JSONObject -> map.putMap(key, value.toReadableMap())
        is JSONArray -> map.putArray(key, value.toReadableArray())
        is Number -> map.putDouble(key, value.toDouble())
        is Boolean -> map.putBoolean(key, value)
        is String -> map.putString(key, value)
        JSONObject.NULL -> map.putNull(key)
        else -> error("Unsupported value for \"$key\" in $ASSET: $value")
      }
    }
    return map
  }

  private fun JSONArray.toReadableArray(): JavaOnlyArray {
    val array = JavaOnlyArray()
    for (index in 0 until length()) {
      when (val value = get(index)) {
        is JSONObject -> array.pushMap(value.toReadableMap())
        is JSONArray -> array.pushArray(value.toReadableArray())
        is Number -> array.pushDouble(value.toDouble())
        is Boolean -> array.pushBoolean(value)
        is String -> array.pushString(value)
        JSONObject.NULL -> array.pushNull()
        else -> error("Unsupported array value in $ASSET: $value")
      }
    }
    return array
  }
}
