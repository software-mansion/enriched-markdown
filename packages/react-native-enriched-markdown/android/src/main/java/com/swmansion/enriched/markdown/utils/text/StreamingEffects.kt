package com.swmansion.enriched.markdown.utils.text

import android.content.Context
import android.util.Log
import com.facebook.react.bridge.ColorPropConverter
import com.facebook.react.bridge.ReadableMap

/**
 * The core's streaming effects (StreamingEffects.hpp) for one text view: how its newest characters
 * look, from their age (fade) or their distance from the end of the text (gradient). Indices are
 * UTF-16 offsets; times are seconds on the [System.nanoTime] clock.
 */
class StreamingEffects {
  // `code` is the core's StreamingEffectType, as jni-adapter.cpp reads it.
  enum class Type(
    val code: Int,
  ) {
    NONE(0),
    FADE(1),
    GRADIENT(2),
  }

  // 0 without the native library (JVM tests): every call is a no-op.
  private var handle: Long =
    try {
      nativeCreate()
    } catch (e: UnsatisfiedLinkError) {
      0L
    }

  fun configure(config: Config) {
    if (handle == 0L) return
    with(config) {
      nativeConfigure(handle, type.code, durationSeconds, length, startColor != null, startColor ?: 0, endColor != null, endColor ?: 0)
    }
  }

  fun noteArrival(
    start: Int,
    end: Int,
    time: Double,
  ) {
    if (handle != 0L) nativeNoteArrival(handle, start, end, time)
  }

  fun finish(time: Double) {
    if (handle != 0L) nativeFinish(handle, time)
  }

  fun reset() {
    if (handle != 0L) nativeReset(handle)
  }

  fun changesOverTime(time: Double): Boolean = handle != 0L && nativeChangesOverTime(handle, time)

  /** The characters drawn differently at [time], or null when none. */
  fun animatedRange(time: Double): IntRange? {
    if (handle == 0L) return null
    val packed = nativeAnimatedRange(handle, time)
    if (packed < 0) return null
    val start = (packed ushr 32).toInt()
    val length = (packed and 0xFFFFFFFFL).toInt()
    return start until start + length
  }

  /** The looks of [count] characters from [start]: each tint (ARGB), its amount and the opacity. */
  fun looks(
    start: Int,
    count: Int,
    time: Double,
    tints: IntArray,
    tintAmounts: FloatArray,
    opacities: FloatArray,
  ) {
    if (handle != 0L) nativeLooks(handle, start, count, time, tints, tintAmounts, opacities)
  }

  fun release() {
    if (handle != 0L) {
      nativeDestroy(handle)
      handle = 0L
    }
  }

  protected fun finalize() {
    release()
  }

  /** `streamingConfig.animation` and its options, as the managers receive them. */
  data class Config(
    val type: Type = Type.FADE,
    val durationSeconds: Double = 0.2,
    val length: Int = 20,
    val startColor: Int? = null,
    val endColor: Int? = null,
  ) {
    companion object {
      fun from(
        config: ReadableMap?,
        context: Context,
      ): Config {
        val defaults = Config()
        if (config == null) return defaults
        val raw = config.toHashMap()

        fun color(key: String): Int? = raw[key]?.let { ColorPropConverter.getColor(it, context) }
        return Config(
          type =
            when (raw["animation"]) {
              "gradient" -> Type.GRADIENT
              "none" -> Type.NONE
              else -> Type.FADE
            },
          durationSeconds = (raw["animationDuration"] as? Number)?.toDouble()?.takeIf { it > 0 }?.div(1000) ?: defaults.durationSeconds,
          length = (raw["animationLength"] as? Number)?.toInt()?.takeIf { it > 0 } ?: defaults.length,
          startColor = color("animationStartColor"),
          endColor = color("animationEndColor"),
        )
      }
    }
  }

  companion object {
    init {
      try {
        System.loadLibrary("react_codegen_EnrichedMarkdownTextSpec")
      } catch (e: UnsatisfiedLinkError) {
        Log.e("StreamingEffects", "Failed to load native library", e)
      }
    }

    fun now(): Double = System.nanoTime() / 1e9

    @JvmStatic private external fun nativeCreate(): Long

    @JvmStatic private external fun nativeDestroy(handle: Long)

    @JvmStatic private external fun nativeConfigure(
      handle: Long,
      type: Int,
      duration: Double,
      length: Int,
      hasStartColor: Boolean,
      startColor: Int,
      hasEndColor: Boolean,
      endColor: Int,
    )

    @JvmStatic private external fun nativeNoteArrival(
      handle: Long,
      start: Int,
      end: Int,
      time: Double,
    )

    @JvmStatic private external fun nativeFinish(
      handle: Long,
      time: Double,
    )

    @JvmStatic private external fun nativeReset(handle: Long)

    @JvmStatic private external fun nativeChangesOverTime(
      handle: Long,
      time: Double,
    ): Boolean

    @JvmStatic private external fun nativeAnimatedRange(
      handle: Long,
      time: Double,
    ): Long

    @JvmStatic private external fun nativeLooks(
      handle: Long,
      start: Int,
      count: Int,
      time: Double,
      tints: IntArray,
      tintAmounts: FloatArray,
      opacities: FloatArray,
    )
  }
}
