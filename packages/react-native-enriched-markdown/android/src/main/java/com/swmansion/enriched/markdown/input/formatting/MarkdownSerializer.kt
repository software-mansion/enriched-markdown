package com.swmansion.enriched.markdown.input.formatting

import android.util.Log
import com.swmansion.enriched.markdown.input.editing.ZWSP
import com.swmansion.enriched.markdown.input.model.BlockRange
import com.swmansion.enriched.markdown.input.model.FormattingRange

/**
 * Markdown export for the input. The serialization itself lives in the shared C++ input
 * core (`cpp/input`, the same code iOS and web run), which knows nothing about the
 * editor's empty-line ZWSP anchor; this wrapper strips it and shifts the ranges first.
 */
object MarkdownSerializer {
  private const val TAG = "MarkdownSerializer"
  private const val FORMATTING_STRIDE = 3
  private const val BLOCK_STRIDE = 5

  init {
    try {
      // The unit tests load a host build of the input core under another name; see build.gradle.
      System.loadLibrary(System.getProperty("enriched.markdown.input.library") ?: "react_codegen_EnrichedMarkdownTextSpec")
    } catch (e: UnsatisfiedLinkError) {
      Log.e(TAG, "Failed to load native library", e)
    }
  }

  /**
   * [formatting] is `(type, start, end)` per range and [blocks] is
   * `(type, start, end, level, ordinal)` per range; [urls] runs parallel to [formatting].
   * Returns null on any failure.
   */
  private external fun nativeSerialize(
    text: String,
    formatting: IntArray,
    urls: Array<String?>,
    blocks: IntArray,
  ): String?

  /**
   * Single choke point for scrubbing the empty-line ZWSP anchor out of anything
   * bound for JS (serialized markdown here, plain text in `InputEventEmitter`).
   * Route new output paths through this rather than scattering `replace(ZWSP, "")`
   * calls, so the anchor can never leak because one path forgot to strip.
   */
  fun stripZwsp(text: String): String = text.replace(ZWSP.toString(), "")

  /**
   * Serializes [text] with its inline [ranges] and [blockRanges] (one per line, sorted by
   * start). A block's marker is derived by the core from its type, level and ordinal, so the
   * ordinal is written as given. An empty list item serializes to a bare marker. If the
   * native core is unavailable the text comes back without markup.
   */
  fun serialize(
    text: String,
    ranges: List<FormattingRange>,
    blockRanges: List<BlockRange> = emptyList(),
  ): String {
    if (text.isEmpty()) return ""

    // Positions of the anchors in [text]; offsets shift left by the anchors before them.
    var anchors = IntArray(0)
    var anchorCount = 0
    var index = text.indexOf(ZWSP)
    while (index >= 0) {
      if (anchorCount == anchors.size) anchors = anchors.copyOf(maxOf(4, anchors.size * 2))
      anchors[anchorCount++] = index
      index = text.indexOf(ZWSP, index + 1)
    }
    val plainText = if (anchorCount == 0) text else stripZwsp(text)

    fun shifted(offset: Int): Int {
      val clamped = offset.coerceIn(0, text.length)
      if (anchorCount == 0) return clamped
      var low = 0
      var high = anchorCount
      while (low < high) {
        val mid = (low + high) ushr 1
        if (anchors[mid] < clamped) low = mid + 1 else high = mid
      }
      return clamped - low
    }

    val formatting = IntArray(ranges.size * FORMATTING_STRIDE)
    val urls = arrayOfNulls<String>(ranges.size)
    var formattingCount = 0
    for (range in ranges) {
      val start = shifted(range.start)
      val end = shifted(range.end)
      // A style that covered only an anchor has nothing left to wrap.
      if (start >= end) continue
      val base = formattingCount * FORMATTING_STRIDE
      formatting[base] = range.type.ordinal
      formatting[base + 1] = start
      formatting[base + 2] = end
      urls[formattingCount] = range.url
      formattingCount++
    }

    val blocks = IntArray(blockRanges.size * BLOCK_STRIDE)
    for ((i, block) in blockRanges.withIndex()) {
      val base = i * BLOCK_STRIDE
      blocks[base] = block.type.ordinal
      blocks[base + 1] = shifted(block.start)
      blocks[base + 2] = shifted(block.end)
      blocks[base + 3] = block.level
      blocks[base + 4] = block.ordinal
    }

    return try {
      nativeSerialize(
        plainText,
        formatting.copyOf(formattingCount * FORMATTING_STRIDE),
        urls.copyOf(formattingCount),
        blocks,
      )
    } catch (e: UnsatisfiedLinkError) {
      Log.e(TAG, "Native input serializer unavailable", e)
      null
    } ?: plainText
  }
}
