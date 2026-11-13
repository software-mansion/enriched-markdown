package com.swmansion.enriched.markdown.input.formatting

import android.util.Log
import com.swmansion.enriched.markdown.input.editing.ZWSP
import com.swmansion.enriched.markdown.input.model.BlockRange
import com.swmansion.enriched.markdown.input.model.BlockType
import com.swmansion.enriched.markdown.input.model.FormattingRange
import com.swmansion.enriched.markdown.input.model.StyleType

data class ParseResult(
  val plainText: String,
  val formattingRanges: List<FormattingRange>,
  val blockRanges: List<BlockRange> = emptyList(),
)

/**
 * Markdown import for the input. The parsing itself lives in the shared C++ input core
 * (`cpp/input`, the same code iOS and web run); this wrapper only converts its packed
 * result into the editor's model and seeds the empty-line anchor the editor needs.
 */
object InputParser {
  private const val TAG = "InputParser"
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
   * Returns `{ String text, IntArray formatting, IntArray blocks, Array<String?> urls }`,
   * where `formatting` is `(type, start, end)` per range, `blocks` is
   * `(type, start, end, level, ordinal)` per range and `urls` runs parallel to
   * `formatting`; null on any failure.
   */
  private external fun nativeParse(markdown: String): Array<Any?>?

  fun parseToPlainTextAndRanges(rawMarkdown: String): ParseResult {
    // U+200B is the editor's reserved empty-list anchor and is stripped from every
    // output path; strip it from incoming markdown too (web paste, JS-supplied
    // values) so a foreign copy can't seed a stray anchor into the buffer.
    val markdown = MarkdownSerializer.stripZwsp(rawMarkdown)
    if (markdown.isEmpty()) {
      return ParseResult("", emptyList(), emptyList())
    }

    val packed =
      try {
        nativeParse(markdown)
      } catch (e: UnsatisfiedLinkError) {
        Log.e(TAG, "Native input parser unavailable", e)
        null
      } ?: return ParseResult(markdown, emptyList(), emptyList())

    val plainText = packed[0] as String
    val formatting = packed[1] as IntArray
    val blocks = packed[2] as IntArray

    @Suppress("UNCHECKED_CAST")
    val urls = packed[3] as Array<String?>

    val styleTypes = StyleType.entries
    val blockTypes = BlockType.entries

    val formattingRanges = ArrayList<FormattingRange>(formatting.size / FORMATTING_STRIDE)
    for (i in 0 until formatting.size / FORMATTING_STRIDE) {
      val base = i * FORMATTING_STRIDE
      val type = styleTypes.getOrNull(formatting[base]) ?: continue
      formattingRanges.add(FormattingRange(type, formatting[base + 1], formatting[base + 2], urls.getOrNull(i)))
    }

    val blockRanges = ArrayList<BlockRange>(blocks.size / BLOCK_STRIDE)
    for (i in 0 until blocks.size / BLOCK_STRIDE) {
      val base = i * BLOCK_STRIDE
      val type = blockTypes.getOrNull(blocks[base]) ?: continue
      blockRanges.add(BlockRange(type, blocks[base + 1], blocks[base + 2], blocks[base + 3], blocks[base + 4]))
    }

    return seedEmptyListAnchors(ParseResult(plainText, formattingRanges, blockRanges))
  }

  /**
   * The editor draws an empty list item (and indents its caret) only when its line holds a
   * ZWSP, and keeps such anchors away from the caret too. The core returns an empty item as
   * a zero-length block on an empty line, so seed the anchor here and shift every range
   * after it, the mirror of what [MarkdownSerializer] strips before exporting.
   */
  private fun seedEmptyListAnchors(parsed: ParseResult): ParseResult {
    val seeds =
      parsed.blockRanges
        .filter { it.type in BlockType.LIST_ITEMS && it.length == 0 }
        .map { it.start }
    if (seeds.isEmpty()) return parsed

    val text = StringBuilder(parsed.plainText.length + seeds.size)
    var copied = 0
    for (seed in seeds) {
      text.append(parsed.plainText, copied, seed).append(ZWSP)
      copied = seed
    }
    text.append(parsed.plainText, copied, parsed.plainText.length)

    // Offset o moves right by the number of anchors inserted before it.
    fun shifted(offset: Int): Int {
      var low = 0
      var high = seeds.size
      while (low < high) {
        val mid = (low + high) ushr 1
        if (seeds[mid] < offset) low = mid + 1 else high = mid
      }
      return offset + low
    }

    val formattingRanges =
      parsed.formattingRanges.map { FormattingRange(it.type, shifted(it.start), shifted(it.end), it.url) }
    val blockRanges =
      parsed.blockRanges.map { block ->
        val start = shifted(block.start)
        val isSeeded = block.type in BlockType.LIST_ITEMS && block.length == 0
        BlockRange(block.type, start, if (isSeeded) start + 1 else shifted(block.end), block.level, block.ordinal)
      }
    return ParseResult(text.toString(), formattingRanges, blockRanges)
  }
}
