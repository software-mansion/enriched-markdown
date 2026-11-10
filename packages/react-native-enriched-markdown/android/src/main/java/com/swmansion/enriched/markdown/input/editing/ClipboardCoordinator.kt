package com.swmansion.enriched.markdown.input.editing

import android.text.Editable
import com.swmansion.enriched.markdown.input.detection.DetectorPipeline
import com.swmansion.enriched.markdown.input.formatting.BlockStore
import com.swmansion.enriched.markdown.input.formatting.FormattingStore
import com.swmansion.enriched.markdown.input.formatting.MarkdownSerializer
import com.swmansion.enriched.markdown.input.model.BlockRange
import com.swmansion.enriched.markdown.input.model.FormattingRange

class ClipboardCoordinator(
  private val formattingStore: FormattingStore,
  private val blockStore: BlockStore,
  private val detectorPipeline: DetectorPipeline,
) {
  fun allRangesForSerialization(editable: Editable?): List<FormattingRange> {
    if (editable == null) return formattingStore.allRanges
    val transient = detectorPipeline.allTransientFormattingRanges(editable)
    if (transient.isEmpty()) return formattingStore.allRanges
    return formattingStore.allRanges + transient
  }

  fun serializeFullDocument(
    text: String,
    editable: Editable?,
  ): String = MarkdownSerializer.serialize(text, allRangesForSerialization(editable), blockStore.allRanges)

  fun serializeSelectedRange(
    fullText: String,
    selStart: Int,
    selEnd: Int,
    editable: Editable?,
  ): String? {
    if (selStart >= selEnd) return null
    val selectedText = fullText.substring(selStart, selEnd)

    val clippedRanges = mutableListOf<FormattingRange>()
    for (range in allRangesForSerialization(editable)) {
      if (range.end <= selStart || range.start >= selEnd) continue
      val clippedStart = maxOf(range.start, selStart)
      val clippedEnd = minOf(range.end, selEnd)
      clippedRanges.add(FormattingRange(range.type, clippedStart - selStart, clippedEnd - selStart, range.url))
    }

    val clippedBlockRanges = mutableListOf<BlockRange>()
    for (block in blockStore.allRanges) {
      if (block.end <= selStart || block.start >= selEnd) continue
      val clippedStart = maxOf(block.start, selStart)
      val clippedEnd = minOf(block.end, selEnd)
      // The core writes the ordinal it is given, so a copy of items 3 and 4 keeps "3." and "4.".
      clippedBlockRanges.add(BlockRange(block.type, clippedStart - selStart, clippedEnd - selStart, block.level, block.ordinal))
    }

    return MarkdownSerializer.serialize(selectedText, clippedRanges, clippedBlockRanges)
  }
}
