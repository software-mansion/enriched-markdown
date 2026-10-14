package com.swmansion.enriched.markdown.codehighlight

import android.util.Log
import android.util.LruCache
import java.nio.ByteBuffer
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Tokenizes UTF-8 code for a fence language into flat `(start, end, tokenType)` triplets, with
 * UTF-16 offsets into the code.
 */
internal fun interface SyntaxTokenSource {
  fun tokenize(
    code: ByteArray,
    language: String,
  ): IntArray
}

/** The compiled grammars, or no tokens at all when the native library failed to load. */
internal object NativeSyntaxTokenSource : SyntaxTokenSource {
  private val unavailable = AtomicBoolean(false)

  override fun tokenize(
    code: ByteArray,
    language: String,
  ): IntArray {
    if (unavailable.get()) return EMPTY
    return try {
      CodeHighlighterNative.highlight(code, language)
    } catch (e: LinkageError) {
      // A library that fails to load arrives as ExceptionInInitializerError on the first call and
      // NoClassDefFoundError on later ones; a missing symbol, as UnsatisfiedLinkError.
      if (unavailable.compareAndSet(false, true)) {
        Log.e("CodeHighlighter", "Native library unavailable, code blocks render unhighlighted", e)
      }
      EMPTY
    }
  }

  private val EMPTY = IntArray(0)
}

/**
 * Tokens by language and code, so re-rendering an unchanged block does not parse it again: a lazy
 * list item scrolled back into view, or a configuration or theme change, renders every block anew.
 * Keyed by a SHA-256 of the language and the code's UTF-8 bytes, so an entry holds its tokens and a
 * digest rather than a copy of the code; on a miss the same bytes go to the [source]. Bounded by
 * approximate size in bytes; [android.util.LruCache] synchronizes, so render workers can share one.
 *
 * Two workers missing the same key at once both tokenize it; the result is identical, so the
 * duplicated work is the only cost, and it is cheaper than holding a lock across a parse.
 */
internal class SyntaxTokenCache(
  private val source: SyntaxTokenSource,
  maxSizeBytes: Int = DEFAULT_MAX_SIZE_BYTES,
) {
  private val cache =
    object : LruCache<ByteBuffer, IntArray>(maxSizeBytes) {
      // The digest is charged too, so blocks without tokens, e.g. in an unknown language, are
      // still evicted.
      override fun sizeOf(
        key: ByteBuffer,
        value: IntArray,
      ): Int = key.capacity() + value.size * Int.SIZE_BYTES
    }

  /** Flat `(start, end, tokenType)` triplets with UTF-16 offsets into [code]. */
  fun tokens(
    code: String,
    language: String,
  ): IntArray {
    val bytes = code.toByteArray(Charsets.UTF_8)
    val key = cacheKey(bytes, language)
    cache.get(key)?.let { return it }
    return source.tokenize(bytes, language).also { cache.put(key, it) }
  }

  private fun cacheKey(
    code: ByteArray,
    language: String,
  ): ByteBuffer {
    val digest = MessageDigest.getInstance("SHA-256")
    // A fence language never contains a newline, so the digested input cannot be ambiguous.
    digest.update("$language\n".toByteArray(Charsets.UTF_8))
    digest.update(code)
    // ByteBuffer compares and hashes by content, unlike a bare ByteArray.
    return ByteBuffer.wrap(digest.digest())
  }

  companion object {
    // iOS's cost limit. The seam caps a block at 50 KB of code, so one entry never fills it.
    const val DEFAULT_MAX_SIZE_BYTES = 4 * 1024 * 1024
  }
}
