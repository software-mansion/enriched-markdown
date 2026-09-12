package com.swmansion.enriched.markdown.parser

import android.util.Log

data class Md4cFlags(
  val underline: Boolean = false,
  val latexMath: Boolean = false,
  val superscript: Boolean = false,
  val subscript: Boolean = false,
  val highlight: Boolean = false,
  val permissiveAutolinks: Boolean = true,
  val hardSoftBreaks: Boolean = false,
  val preserveBlankLines: Boolean = false,
  val admonitions: Boolean = false,
) {
  companion object {
    val DEFAULT = Md4cFlags()
  }
}

class Parser {
  companion object {
    init {
      try {
        System.loadLibrary("enriched_markdown_parser")
      } catch (e: UnsatisfiedLinkError) {
        Log.e("MarkdownParser", "Failed to load native library", e)
      }
    }

    @JvmStatic
    private external fun nativeParseMarkdown(
      markdown: String,
      flags: Md4cFlags,
    ): MarkdownASTNode?

    val shared: Parser = Parser()
  }

  fun parseMarkdown(
    markdown: String,
    flags: Md4cFlags = Md4cFlags.DEFAULT,
  ): MarkdownASTNode? {
    if (markdown.isBlank()) {
      return null
    }

    try {
      val ast = nativeParseMarkdown(markdown, flags)
      if (ast != null) {
        return ast
      }
      Log.w("MarkdownParser", "Native parser returned null")
      return null
    } catch (e: Exception) {
      Log.e("MarkdownParser", "MD4C parsing failed: ${e.message}", e)
      return null
    }
  }
}
