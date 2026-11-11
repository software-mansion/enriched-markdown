package com.swmansion.enriched.markdown.segments

import android.text.NoCopySpan
import android.text.SpannableStringBuilder
import android.text.Spanned
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.spans.ImageSpan
import java.util.concurrent.atomic.AtomicLong

/**
 * Replaces the text from [start] on with [tail], dropping the spans of the text it replaces
 * first: `replace` would stretch a span over exactly that text across [tail]. A view's own
 * bookkeeping spans (its watchers and selection, all [NoCopySpan]) stay.
 */
fun SpannableStringBuilder.replaceTail(
  start: Int,
  tail: Spanned,
) {
  for (span in getSpans(start, length, Any::class.java)) {
    if (span !is NoCopySpan && getSpanStart(span) >= start) removeSpan(span)
  }
  replace(start, length, tail)
}

/** What [TextRenderCache.render] needs from a render of a text segment's nodes. */
class TextRenderResult(
  val styledText: SpannableStringBuilder,
  val imageSpans: List<ImageSpan>,
  val needsJustify: Boolean,
  val lastElementMarginBottom: Float,
  val taskItemCount: Int,
  val blockStarts: IntArray,
  val blockTaskStarts: IntArray,
)

/** [styledText], just rendered by this renderer, with what the renderer collected along. */
fun Renderer.textRenderResult(
  styledText: SpannableStringBuilder,
  needsJustify: Boolean,
) = TextRenderResult(
  styledText = styledText,
  imageSpans = getCollectedImageSpans().toList(),
  needsJustify = needsJustify,
  lastElementMarginBottom = getLastElementMarginBottom(),
  taskItemCount = getTaskItemCount(),
  blockStarts = getBlockStarts(),
  blockTaskStarts = getBlockTaskStarts(),
)

/**
 * What a view's previous render produced for its text segments, so the next one reuses it
 * while the document streams. Confined to the thread the view renders on.
 *
 * - A text segment whose nodes and first task index are unchanged is handed over as the same
 *   [RenderedSegment.Text]. The reconciler keeps its view as it is, so its buffer is not read
 *   again.
 * - The last text segment, the one a stream grows, also keeps where each top-level node starts
 *   in its text. When the new segment starts with the same nodes, only the nodes from the first
 *   changed one on render, and the view patches its live buffer from there: the result is only
 *   that patch ([RenderedSegment.Text.patch]), so no update copies the text. Rendering starts at
 *   the old last node at the latest, whose trailing margin was trimmed, and at the new last node
 *   at the latest, which still ends in the spacing before the nodes that are gone (a link
 *   reference definition that completes renders nothing).
 *
 * Drop it with [clear] whenever views are recreated.
 */
class TextRenderCache {
  // A segment of the previous render, and what finding it again takes.
  private class Entry(
    val segment: RenderedSegment.Text,
    val baseSignature: Long,
    val startingTaskIndex: Int,
    val taskItemCount: Int,
  )

  private class Growing(
    val entry: Entry,
    val nodeSignatures: LongArray,
    val blockStarts: IntArray,
    val blockTaskStarts: IntArray,
    val textLength: Int,
    val imageSpans: List<ImageSpan>,
    // Where each of [imageSpans] starts in the text.
    val imageStarts: IntArray,
  )

  private var previous: List<Entry> = emptyList()
  private var growing: Growing? = null
  private val current = mutableListOf<Entry>()
  private var available = mutableListOf<Entry>()
  private var key: Any? = null

  fun clear() {
    previous = emptyList()
    growing = null
    key = null
  }

  /** Starts a render; [renderKey] identifies everything besides the nodes that shapes the text. */
  fun begin(renderKey: Any) {
    if (renderKey != key) clear()
    key = renderKey
    current.clear()
    available = previous.toMutableList()
  }

  fun end() {
    previous = current.toList()
  }

  /**
   * The rendered segment for [nodes], whose first task index is [startingTaskIndex]. [isLast]
   * marks the segment a stream grows. [render] renders nodes from a task index in full.
   */
  fun render(
    nodes: List<MarkdownASTNode>,
    startingTaskIndex: Int,
    isLast: Boolean,
    render: (List<MarkdownASTNode>, Int) -> TextRenderResult,
  ): Pair<RenderedSegment.Text, Int> {
    val nodeSignatures = LongArray(nodes.size) { SegmentSignature.signatureForNode(nodes[it]) }
    val base = baseSignature(nodeSignatures)

    available.firstOrNull { it.baseSignature == base && it.startingTaskIndex == startingTaskIndex }?.let { reused ->
      available.remove(reused)
      current.add(reused)
      return reused.segment to reused.taskItemCount
    }

    val resumed = if (isLast) resume(nodes, nodeSignatures, startingTaskIndex, base, render) else null
    if (resumed != null) {
      current.add(resumed)
      return resumed.segment to resumed.taskItemCount
    }

    val full = render(nodes, startingTaskIndex)
    val entry = Entry(segmentOf(full, base, startingTaskIndex), base, startingTaskIndex, full.taskItemCount)
    if (isLast) {
      // Read before the view adopts the buffer.
      val imageStarts = IntArray(full.imageSpans.size) { full.styledText.getSpanStart(full.imageSpans[it]) }
      growing =
        Growing(entry, nodeSignatures, full.blockStarts, full.blockTaskStarts, full.styledText.length, full.imageSpans, imageStarts)
    }
    current.add(entry)
    return entry.segment to full.taskItemCount
  }

  private fun resume(
    nodes: List<MarkdownASTNode>,
    nodeSignatures: LongArray,
    startingTaskIndex: Int,
    base: Long,
    render: (List<MarkdownASTNode>, Int) -> TextRenderResult,
  ): Entry? {
    val old = growing ?: return null
    if (old.entry.startingTaskIndex != startingTaskIndex) return null
    var common = 0
    while (common < nodes.size && common < old.nodeSignatures.size && nodeSignatures[common] == old.nodeSignatures[common]) {
      common++
    }
    // No later than the last node of either render (see the class comment).
    val from = minOf(common, old.nodeSignatures.size - 1, nodes.size - 1)
    if (from <= 0) return null
    val start = old.blockStarts[from]
    if (start > old.textLength) return null

    val tail = render(nodes.subList(from, nodes.size), old.blockTaskStarts[from])
    val tailImageSpans = tail.imageSpans
    val kept = old.imageStarts.indices.filter { old.imageStarts[it] in 0 until start }
    val imageSpans = kept.map { old.imageSpans[it] } + tailImageSpans
    val imageStarts = kept.map { old.imageStarts[it] } + tailImageSpans.map { start + tail.styledText.getSpanStart(it) }

    val rendered =
      RenderedSegment.Text(
        styledText = null,
        imageSpans = imageSpans,
        needsJustify = tail.needsJustify,
        lastElementMarginBottom = tail.lastElementMarginBottom,
        signature = signatureOf(base, startingTaskIndex, tail.taskItemCount),
        revision = nextRevision(),
        patch = TextPatch(old.entry.segment.revision, start, tail.styledText, tailImageSpans),
      )
    val entry = Entry(rendered, base, startingTaskIndex, tail.taskItemCount)
    growing =
      Growing(
        entry,
        nodeSignatures,
        old.blockStarts.copyOf(from) + tail.blockStarts.map { it + start },
        old.blockTaskStarts.copyOf(from) + tail.blockTaskStarts,
        start + tail.styledText.length,
        imageSpans,
        imageStarts.toIntArray(),
      )
    return entry
  }

  companion object {
    private val revisions = AtomicLong()

    private fun nextRevision(): Long = revisions.incrementAndGet()

    private fun baseSignature(nodeSignatures: LongArray): Long =
      SegmentSignature.signatureForNodeSignatures(nodeSignatures) xor SegmentSignature.TEXT_KIND_SALT

    private fun signatureOf(
      base: Long,
      startingTaskIndex: Int,
      taskItemCount: Int,
    ) = SegmentSignature.withTaskIndexOffset(base, startingTaskIndex, hasTasks = taskItemCount > startingTaskIndex)

    /** The segment for a full render of [nodes], without a cache. */
    fun segmentOf(
      nodes: List<MarkdownASTNode>,
      text: TextRenderResult,
      startingTaskIndex: Int,
    ) = segmentOf(text, baseSignature(LongArray(nodes.size) { SegmentSignature.signatureForNode(nodes[it]) }), startingTaskIndex)

    private fun segmentOf(
      text: TextRenderResult,
      base: Long,
      startingTaskIndex: Int,
    ) = RenderedSegment.Text(
      styledText = text.styledText,
      imageSpans = text.imageSpans,
      needsJustify = text.needsJustify,
      lastElementMarginBottom = text.lastElementMarginBottom,
      signature = signatureOf(base, startingTaskIndex, text.taskItemCount),
      revision = nextRevision(),
    )
  }
}
