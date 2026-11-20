package com.swmansion.enriched.markdown.math

import android.util.LruCache
import io.ratex.DisplayList
import io.ratex.RaTeXEngine

/**
 * Parsed equations, so a render only parses the ones it has not seen. Streaming re-renders the
 * whole document on every token, which would otherwise parse every equation in it again each time.
 *
 * Keyed on everything the parse takes. The font size is not among them: the display list is in em,
 * and [io.ratex.RaTeXRenderer] scales it. A rejected expression is not cached, so it is parsed -
 * and reported - again; that only costs anything while the content is broken.
 */
internal class DisplayListCache(
  maxSize: Int,
  private val parse: (latex: String, displayMode: Boolean, color: Int) -> DisplayList,
) {
  private data class Key(
    val latex: String,
    val displayMode: Boolean,
    val color: Int,
  )

  // LruCache locks around each access, so render threads of different views can share it.
  private val entries = LruCache<Key, DisplayList>(maxSize)

  fun get(
    latex: String,
    displayMode: Boolean,
    color: Int,
  ): DisplayList {
    val key = Key(latex, displayMode, color)
    return entries.get(key) ?: parse(latex, displayMode, color).also { entries.put(key, it) }
  }

  companion object {
    private const val MAX_SIZE = 256

    val shared = DisplayListCache(MAX_SIZE) { latex, displayMode, color -> RaTeXEngine.parseBlocking(latex, displayMode, color) }
  }
}
