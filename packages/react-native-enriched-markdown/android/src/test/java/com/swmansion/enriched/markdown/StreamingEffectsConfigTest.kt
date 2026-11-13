package com.swmansion.enriched.markdown

import android.graphics.Color
import com.facebook.react.bridge.JavaOnlyArray
import com.facebook.react.bridge.JavaOnlyMap
import com.facebook.react.bridge.ReadableMap
import com.swmansion.enriched.markdown.utils.text.StreamingEffects
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class StreamingEffectsConfigTest {
  // ReadableNativeMap's toHashMap turns nested maps into HashMaps; JavaOnlyMap's keeps them.
  private class NativeLikeMap(
    private val map: JavaOnlyMap,
  ) : ReadableMap by map {
    override fun toHashMap(): HashMap<String, Any?> =
      HashMap(map.toHashMap().mapValues { (_, value) -> if (value is ReadableMap) value.toHashMap() else value })
  }

  @Test
  fun takesAPlatformColorAndAProcessedOne() {
    val context = RuntimeEnvironment.getApplication()
    val platformColor = JavaOnlyMap.of("resource_paths", JavaOnlyArray.of("@android:color/holo_red_light"))
    val config =
      StreamingEffects.Config.from(
        NativeLikeMap(
          JavaOnlyMap.of(
            "animation",
            "gradient",
            "animationStartColor",
            platformColor,
            "animationEndColor",
            Color.BLUE.toDouble(),
          ),
        ),
        context,
      )
    assertEquals(context.getColor(android.R.color.holo_red_light), config.startColor)
    assertEquals(Color.BLUE, config.endColor)
  }
}
