package com.swmansion.enriched.markdown.parser

import android.util.Log
import com.swmansion.enriched.markdown.utils.common.FeatureFlags
import com.swmansion.enriched.markdown.utils.common.LinkRegexConfig

data class Md4cFlags(
  val underline: Boolean = false,
  val latexMath: Boolean = FeatureFlags.IS_MATH_ENABLED,
  val superscript: Boolean = false,
  val subscript: Boolean = false,
  val highlight: Boolean = false,
  val permissiveAutolinks: Boolean = true,
  val hardSoftBreaks: Boolean = false,
  val preserveBlankLines: Boolean = false,
  val admonitions: Boolean = true,
) {
  companion object {
    val DEFAULT = Md4cFlags()
  }
}

class Parser {
  companion object {
    init {
      try {
        // Library name must follow react_codegen_<ComponentName> convention
        // required by React Native Fabric's CMake build system.
        // md4c parser is bundled in the same shared library to avoid
        // multiple library loading and complex linking dependencies.
        System.loadLibrary("react_codegen_EnrichedMarkdownTextSpec")
      } catch (e: UnsatisfiedLinkError) {
        Log.e("MarkdownParser", "Failed to load native library", e)
      }
    }

    @JvmStatic
    private external fun nativeParseMarkdown(
      markdown: String,
      flags: Md4cFlags,
      isGFM: Boolean,
      textLinkRegex: LinkRegexConfig?,
      inlineCodeLinkRegex: LinkRegexConfig?,
      activeBlockSlotIds: Array<String>?,
      annotateImages: Boolean,
    ): MarkdownASTNode?

    /**
     * Shared parser instance. Parser is stateless and thread-safe, so it can be reused
     * across all EnrichedMarkdownText instances to avoid unnecessary allocations.
     */
    val shared: Parser = Parser()

    // Render, measure and a nested quote's static measure of one document.
    private const val RECENT_PARSES = 3
  }

  // The measurement pass and the render pass parse the same document with the
  // same options, one after the other and often on different threads; the last
  // few results are kept so a streaming tick parses once. Nothing mutates an AST
  // after parsing, so sharing one is safe.
  private data class ParseKey(
    val markdown: String,
    val flags: Md4cFlags,
    val isGFM: Boolean,
    val linkRegex: LinkRegexConfig?,
    val inlineCodeLinkRegex: LinkRegexConfig?,
    val activeBlockSlotIds: Set<String>,
    val annotateImages: Boolean,
  )

  private val recentParses = ArrayDeque<Pair<ParseKey, MarkdownASTNode>>()
  private val recentParsesLock = Any()

  fun parseMarkdown(
    markdown: String,
    flags: Md4cFlags = Md4cFlags.DEFAULT,
    isGFM: Boolean = true,
    linkRegex: LinkRegexConfig? = null,
    inlineCodeLinkRegex: LinkRegexConfig? = null,
    // Block slots the host has React children for: their nodes get `blockSlotId`
    // and `blockSlotKind` stamped (see core BlockSlots.hpp).
    activeBlockSlotIds: Set<String> = emptySet(),
    // Stamps `imageOccurrenceId` on every image for `imageSources` lookups.
    annotateImages: Boolean = false,
  ): MarkdownASTNode? {
    if (markdown.isBlank()) {
      return null
    }

    val key = ParseKey(markdown, flags, isGFM, linkRegex, inlineCodeLinkRegex, activeBlockSlotIds, annotateImages)
    synchronized(recentParsesLock) {
      recentParses.firstOrNull { it.first == key }?.let { return it.second }
    }
    val ast = parseUncached(markdown, flags, isGFM, linkRegex, inlineCodeLinkRegex, activeBlockSlotIds, annotateImages)
    if (ast != null) {
      synchronized(recentParsesLock) {
        recentParses.addFirst(key to ast)
        while (recentParses.size > RECENT_PARSES) recentParses.removeLast()
      }
    }
    return ast
  }

  private fun parseUncached(
    markdown: String,
    flags: Md4cFlags,
    isGFM: Boolean,
    linkRegex: LinkRegexConfig?,
    inlineCodeLinkRegex: LinkRegexConfig?,
    activeBlockSlotIds: Set<String>,
    annotateImages: Boolean,
  ): MarkdownASTNode? {
    try {
      // Only active patterns cross JNI.
      val ast =
        nativeParseMarkdown(
          markdown,
          flags,
          isGFM,
          linkRegex?.takeIf { it.compiled != null },
          inlineCodeLinkRegex?.takeIf { it.compiledWholeSpan != null },
          activeBlockSlotIds.takeIf { it.isNotEmpty() }?.toTypedArray(),
          annotateImages,
        )

      if (ast != null) {
        return ast
      } else {
        Log.w("MarkdownParser", "Native parser returned null")
        return null
      }
    } catch (e: Exception) {
      Log.e("MarkdownParser", "MD4C parsing failed: ${e.message}", e)
      return null
    }
  }
}
