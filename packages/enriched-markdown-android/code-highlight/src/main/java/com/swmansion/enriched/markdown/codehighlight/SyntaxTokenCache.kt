package com.swmansion.enriched.markdown.codehighlight

import android.util.Log
import android.util.LruCache

/** Tokenizes code for a fence language into flat `(start, end, tokenType)` triplets. */
internal fun interface SyntaxTokenSource {
  fun tokenize(
    code: String,
    language: String,
  ): IntArray
}

/** The compiled grammars, or no tokens at all when the native library failed to load. */
internal object NativeSyntaxTokenSource : SyntaxTokenSource {
  @Volatile
  private var unavailable = false

  override fun tokenize(
    code: String,
    language: String,
  ): IntArray {
    if (unavailable) return EMPTY
    return try {
      CodeHighlighterNative.highlight(code.toByteArray(Charsets.UTF_8), language)
    } catch (e: UnsatisfiedLinkError) {
      unavailable = true
      Log.e("CodeHighlighter", "Native library unavailable, code blocks render unhighlighted", e)
      EMPTY
    }
  }

  private val EMPTY = IntArray(0)
}

/**
 * Tokens by language and code, so re-rendering unchanged markdown - a style change, a streamed
 * message growing below its code - does not parse the block again. Bounded by approximate size in
 * bytes; [android.util.LruCache] synchronizes, so render workers can share one.
 *
 * Two workers missing the same key at once both tokenize it; the result is identical, so the
 * duplicated work is the only cost, and it is cheaper than holding a lock across a parse.
 */
internal class SyntaxTokenCache(
  private val source: SyntaxTokenSource,
  maxSizeBytes: Int = DEFAULT_MAX_SIZE_BYTES,
) {
  private val cache =
    object : LruCache<String, IntArray>(maxSizeBytes) {
      override fun sizeOf(
        key: String,
        value: IntArray,
      ): Int = key.length * Char.SIZE_BYTES + value.size * Int.SIZE_BYTES
    }

  /** Flat `(start, end, tokenType)` triplets with UTF-16 offsets into [code]. */
  fun tokens(
    code: String,
    language: String,
  ): IntArray {
    // A fence language never contains a newline, so the key cannot be ambiguous.
    val key = "$language\n$code"
    cache.get(key)?.let { return it }
    return source.tokenize(code, language).also { cache.put(key, it) }
  }

  companion object {
    // iOS's cost limit. The seam caps a block at 50 KB of code, so one entry never fills it.
    const val DEFAULT_MAX_SIZE_BYTES = 4 * 1024 * 1024
  }
}
