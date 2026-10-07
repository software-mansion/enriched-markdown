package com.swmansion.enriched.markdown.syntaxhighlighting

import android.util.Log

/**
 * JNI binding to the shared tree-sitter seam (`core/cpp/highlight/CodeBlockHighlighter.hpp`),
 * built into `libenriched_markdown_highlight.so` with a fixed set of 14 grammars.
 *
 * Kept to the bare native call: caching, spans and colors sit above it, so this is the only class
 * that knows the library exists.
 */
internal object SyntaxHighlighterNative {
  /** Token types in the seam's `HighlightTokenType` order; `HighlightJni.cpp` pins the count. */
  const val TOKEN_TYPE_COUNT = 14

  init {
    try {
      System.loadLibrary("enriched_markdown_highlight")
    } catch (e: UnsatisfiedLinkError) {
      Log.e("SyntaxHighlighter", "Failed to load native library", e)
    }
  }

  /**
   * Tokenizes [code], given as UTF-8 bytes, with the grammar for the fence [language].
   *
   * Returns flat `(start, end, tokenType)` triplets with offsets in UTF-16 code units, so they
   * index the original `String` directly. The array is empty for a language without a compiled
   * grammar, for code past the seam's cap (50 KB or 2,000 lines), and when parsing fails.
   *
   * Pass `code.toByteArray(Charsets.UTF_8)`, never a `String`: JNI's string accessors hand native
   * code modified UTF-8, which would skew every offset after an emoji.
   */
  external fun highlight(
    code: ByteArray,
    language: String,
  ): IntArray
}
