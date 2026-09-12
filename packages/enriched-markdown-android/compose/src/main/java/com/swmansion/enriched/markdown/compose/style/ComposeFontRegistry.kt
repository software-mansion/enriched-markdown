package com.swmansion.enriched.markdown.compose.style

import android.graphics.Typeface
import com.swmansion.enriched.markdown.utils.text.TypefaceUtils
import java.util.WeakHashMap
import java.util.concurrent.atomic.AtomicInteger

internal object ComposeFontRegistry {
  private val idGenerator = AtomicInteger()
  private val typefaceToKey = WeakHashMap<Typeface, String>()
  private val lock = Any()

  fun register(typeface: Typeface): String =
    synchronized(lock) {
      typefaceToKey.getOrPut(typeface) {
        val key = "compose-font:${idGenerator.incrementAndGet()}"
        TypefaceUtils.registerComposeFont(key, typeface)
        key
      }
    }
}
