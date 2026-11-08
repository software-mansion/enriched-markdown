package com.swmansion.enriched.markdown.utils.common

import com.swmansion.enriched.markdown.parser.Md4cFlags
import com.swmansion.enriched.markdown.parser.Parser

enum class TableStreamingMode {
  HIDDEN,
  PROGRESSIVE,
  ;

  companion object {
    fun fromString(value: String?): TableStreamingMode =
      when (value) {
        "hidden" -> HIDDEN
        else -> PROGRESSIVE
      }
  }
}

enum class CodeBlockStreamingMode {
  HIDDEN,
  PROGRESSIVE,
  ;

  companion object {
    fun fromString(value: String?): CodeBlockStreamingMode =
      when (value) {
        "hidden" -> HIDDEN
        else -> PROGRESSIVE
      }
  }
}

/**
 * How a trailing image paragraph or video block is treated while streaming.
 * PROGRESSIVE shows it as soon as its syntax is complete; HIDDEN waits for a
 * blank line or another block after it, like a table in HIDDEN mode.
 */
enum class MediaStreamingMode {
  HIDDEN,
  PROGRESSIVE,
  ;

  companion object {
    fun fromString(value: String?): MediaStreamingMode =
      when (value) {
        "hidden" -> HIDDEN
        else -> PROGRESSIVE
      }
  }
}

/**
 * The markdown to render plus whether it ends inside a still-open fenced code
 * block (the trailing block whose highlighting/copy chrome the renderer defers).
 */
data class StreamingFilterResult(
  val markdown: String,
  val endsInsideOpenCodeFence: Boolean,
)

/**
 * The markdown to render while a document streams, from the core's streaming
 * session (packages/core/cpp/parser/StreamingSession.hpp) that iOS and the JS
 * block collector share, so every consumer sees the same document: trailing
 * blocks still arriving are withheld and inline syntax still being typed is
 * repaired the way [flags] parse it.
 */
object StreamingMarkdownFilter {
  init {
    Parser.shared // loads the native library
  }

  fun renderableMarkdownForStreaming(
    markdown: String,
    flags: Md4cFlags,
    tableMode: TableStreamingMode = TableStreamingMode.PROGRESSIVE,
    codeBlockMode: CodeBlockStreamingMode = CodeBlockStreamingMode.PROGRESSIVE,
    mediaMode: MediaStreamingMode = MediaStreamingMode.PROGRESSIVE,
  ): StreamingFilterResult =
    nativeRenderableMarkdownForStreaming(
      markdown,
      flags,
      tableMode == TableStreamingMode.HIDDEN,
      codeBlockMode == CodeBlockStreamingMode.HIDDEN,
      mediaMode == MediaStreamingMode.HIDDEN,
    ) ?: StreamingFilterResult(markdown, false)

  @JvmStatic
  private external fun nativeRenderableMarkdownForStreaming(
    markdown: String,
    flags: Md4cFlags,
    hideTables: Boolean,
    hideCodeBlocks: Boolean,
    hideMedia: Boolean,
  ): StreamingFilterResult?
}
