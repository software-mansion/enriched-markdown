package com.swmansion.enriched.markdown.utils.common

import com.swmansion.enriched.markdown.parser.Parser

enum class TableStreamingMode {
  HIDDEN,
  PROGRESSIVE,
}

enum class CodeBlockStreamingMode {
  HIDDEN,
  PROGRESSIVE,
}

/**
 * How a trailing image paragraph or video block is treated while streaming.
 * PROGRESSIVE shows it as soon as its syntax is complete; HIDDEN waits for a
 * blank line or another block after it, like a table in HIDDEN mode.
 */
enum class MediaStreamingMode {
  HIDDEN,
  PROGRESSIVE,
}

/**
 * Filtered markdown plus whether it ends inside a still-open fenced code block
 * (the trailing block whose highlighting/copy chrome the renderer defers).
 */
data class StreamingFilterResult(
  val markdown: String,
  val endsInsideOpenCodeFence: Boolean,
)

/**
 * The pre-parse streaming filter, from the core's single implementation
 * (packages/core/cpp/parser/StreamingFilter.hpp) that iOS and the JS block
 * collector share, so every consumer sees the same document while it streams.
 */
object StreamingMarkdownFilter {
  init {
    Parser.shared // loads the native library
  }

  fun renderableMarkdownForStreaming(
    markdown: String,
    tableMode: TableStreamingMode = TableStreamingMode.PROGRESSIVE,
    codeBlockMode: CodeBlockStreamingMode = CodeBlockStreamingMode.PROGRESSIVE,
    mediaMode: MediaStreamingMode = MediaStreamingMode.PROGRESSIVE,
  ): StreamingFilterResult =
    nativeRenderableMarkdownForStreaming(
      markdown,
      tableMode == TableStreamingMode.HIDDEN,
      codeBlockMode == CodeBlockStreamingMode.HIDDEN,
      mediaMode == MediaStreamingMode.HIDDEN,
    ) ?: StreamingFilterResult(markdown, false)

  @JvmStatic
  private external fun nativeRenderableMarkdownForStreaming(
    markdown: String,
    hideTables: Boolean,
    hideCodeBlocks: Boolean,
    hideMedia: Boolean,
  ): StreamingFilterResult?
}
