package com.swmansion.enriched.markdown.parser

/**
 * Display names for code block fence languages ("py" -> "Python"), from the
 * shared C++ core (cpp/highlight/CodeBlockLanguages.hpp) so every platform
 * labels a fence the same way. When the native library is unavailable the
 * raw fence string is shown instead.
 */
object CodeBlockLanguages {
  // The lookup lives in the parser's native library, which Parser loads.
  init {
    Parser.shared
  }

  @JvmStatic
  private external fun nativeDisplayName(language: String): String

  fun displayName(language: String?): String {
    if (language.isNullOrEmpty()) return ""
    return try {
      nativeDisplayName(language)
    } catch (e: UnsatisfiedLinkError) {
      language
    }
  }
}
