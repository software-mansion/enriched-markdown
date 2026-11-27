package com.swmansion.enriched.markdown.segments

import android.text.NoCopySpan
import android.text.SpannableStringBuilder
import android.text.Spanned
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.renderer.ListRenderer
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.spans.ImageSpan
import java.util.concurrent.atomic.AtomicLong

/**
 * Drops the spans of the replaced text first: `replace` would stretch a span over exactly that
 * text across [tail]. A view's own bookkeeping spans (watchers, selection: all [NoCopySpan]) stay.
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
  // The items of the last top-level list rendered, as [blockStarts] does for nodes.
  val listItemStarts: IntArray = IntArray(0),
  val listItemTaskStarts: IntArray = IntArray(0),
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
  listItemStarts = getTopLevelListItemStarts(),
  listItemTaskStarts = getTopLevelListItemTaskStarts(),
)

/**
 * A view's previous text render, reused while the document streams. Confined to the thread the
 * view renders on; [clear] it whenever views are recreated.
 *
 * An unchanged text segment comes back as the same [RenderedSegment.Text], so the reconciler keeps
 * its view. The last one re-renders from its first changed top-level node (or list item) as a
 * patch, starting no later than the old last node, whose trailing margin was trimmed, and the new
 * last node, which still ends in the spacing before nodes that are gone (a completed link
 * reference definition renders nothing).
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
    // The segment's index among the text segments of its render: only that segment resumes.
    val position: Int,
    val nodeSignatures: LongArray,
    val blockStarts: IntArray,
    val blockTaskStarts: IntArray,
    // Whether the text before each of [blockStarts] ends in "\n" (or is empty): rendering can resume
    // only there.
    val resumable: BooleanArray,
    // The same for the items of the last node when it is a list (ListItems), else empty.
    val items: ListItems,
    val textLength: Int,
    val imageSpans: List<ImageSpan>,
    // Where each of [imageSpans] starts in the text.
    val imageStarts: IntArray,
  )

  // A stream grows a list item by item, and a long list is often a segment's only node: rendering
  // resumes at its first changed item too, with the rest of the list as a continuation
  // (ListRenderer.CONTINUATION_ATTRIBUTE).
  private class ListItems(
    val signatures: LongArray,
    val starts: IntArray,
    val taskStarts: IntArray,
    val resumable: BooleanArray,
  ) {
    companion object {
      val NONE = ListItems(LongArray(0), IntArray(0), IntArray(0), BooleanArray(0))
    }
  }

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
        Growing(
          entry,
          current.size,
          nodeSignatures,
          full.blockStarts,
          full.blockTaskStarts,
          resumableStarts(full.styledText, full.blockStarts),
          listItemsOf(nodes.lastOrNull(), full, 0),
          full.styledText.length,
          full.imageSpans,
          imageStarts,
        )
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
    if (old.position != current.size || old.entry.startingTaskIndex != startingTaskIndex) return null
    var common = 0
    while (common < nodes.size && common < old.nodeSignatures.size && nodeSignatures[common] == old.nodeSignatures[common]) {
      common++
    }
    resumeInList(old, nodes, nodeSignatures, common, startingTaskIndex, base, render)?.let { return it }
    // No later than the last node of either render (see the class comment).
    val from = minOf(common, old.nodeSignatures.size - 1, nodes.size - 1)
    if (from <= 0) return null
    val start = old.blockStarts[from]
    if (start > old.textLength || !old.resumable[from]) return null

    val tail = render(nodes.subList(from, nodes.size), old.blockTaskStarts[from])
    return patched(
      old,
      start,
      tail,
      startingTaskIndex,
      base,
      nodeSignatures,
      old.blockStarts.copyOf(from) + tail.blockStarts.map { it + start },
      old.blockTaskStarts.copyOf(from) + tail.blockTaskStarts,
      old.resumable.copyOf(from) + resumableStarts(tail.styledText, tail.blockStarts),
      listItemsOf(nodes.last(), tail, start),
    )
  }

  // Both renders end in the same list after the same nodes: the list's items from its first
  // changed one on render as a continuation of the items before them.
  private fun resumeInList(
    old: Growing,
    nodes: List<MarkdownASTNode>,
    nodeSignatures: LongArray,
    common: Int,
    startingTaskIndex: Int,
    base: Long,
    render: (List<MarkdownASTNode>, Int) -> TextRenderResult,
  ): Entry? {
    val last = nodes.size - 1
    if (old.nodeSignatures.size != nodes.size || common < last || old.items.signatures.isEmpty()) return null
    val list = nodes[last]
    val signatures = itemSignatures(list) ?: return null
    var commonItems = 0
    while (commonItems < signatures.size && commonItems < old.items.signatures.size &&
      signatures[commonItems] == old.items.signatures[commonItems]
    ) {
      commonItems++
    }
    // An item that rendered nothing (an empty marker a chunk ended on) starts past the trimmed
    // text: rendering resumes at the item before it instead.
    var from = minOf(commonItems, old.items.signatures.size - 1, signatures.size - 1)
    while (from > 0 && (old.items.starts[from] > old.textLength || !old.items.resumable[from])) from--
    if (from <= 0) return null
    val start = old.items.starts[from]

    val tail = render(listOf(continuationOf(list, from)), old.items.taskStarts[from])
    // Items that now render nothing (a link reference definition completing) would leave the text
    // before them ending in the item break a full render trims.
    if (tail.styledText.isEmpty()) return null
    val tailItems = listItemsOf(signatures.copyOfRange(from, signatures.size), tail, start)
    val items =
      if (tailItems === ListItems.NONE) {
        ListItems.NONE
      } else {
        ListItems(
          signatures,
          old.items.starts.copyOf(from) + tailItems.starts,
          old.items.taskStarts.copyOf(from) + tailItems.taskStarts,
          old.items.resumable.copyOf(from) + tailItems.resumable,
        )
      }
    return patched(old, start, tail, startingTaskIndex, base, nodeSignatures, old.blockStarts, old.blockTaskStarts, old.resumable, items)
  }

  // The segment patching the old text from [start] with [tail]; the rest describes the text after it.
  private fun patched(
    old: Growing,
    start: Int,
    tail: TextRenderResult,
    startingTaskIndex: Int,
    base: Long,
    nodeSignatures: LongArray,
    blockStarts: IntArray,
    blockTaskStarts: IntArray,
    resumable: BooleanArray,
    items: ListItems,
  ): Entry {
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
        old.position,
        nodeSignatures,
        blockStarts,
        blockTaskStarts,
        resumable,
        items,
        start + tail.styledText.length,
        imageSpans,
        imageStarts.toIntArray(),
      )
    return entry
  }

  companion object {
    private val revisions = AtomicLong()

    // Ordered lists stop resuming once a number reaches 100: wider numbers widen the marker
    // column of every item (ListRenderer.markerExtraWidth).
    private fun itemSignatures(list: MarkdownASTNode?): LongArray? {
      if (list == null || list.children.isEmpty()) return null
      val ordered = list.type == MarkdownASTNode.NodeType.OrderedList
      if (!ordered && list.type != MarkdownASTNode.NodeType.UnorderedList) return null
      if (ordered && ListRenderer.startNumber(list) + list.children.size > 100) return null
      // An item renders by its list's attributes too (tight or loose, the numbering).
      val listSignature = SegmentSignature.signatureForNode(list.copy(children = emptyList()))
      return LongArray(list.children.size) { listSignature * 31 + SegmentSignature.signatureForNode(list.children[it]) }
    }

    // The items of [list] from [from] on, numbered on from there and without the gap above the list.
    private fun continuationOf(
      list: MarkdownASTNode,
      from: Int,
    ): MarkdownASTNode {
      val attributes = list.attributes + (ListRenderer.CONTINUATION_ATTRIBUTE to "true")
      val numbered =
        if (list.type == MarkdownASTNode.NodeType.OrderedList) {
          attributes + ("start" to (ListRenderer.startNumber(list) + from).toString())
        } else {
          attributes
        }
      return list.copy(attributes = numbered, children = list.children.subList(from, list.children.size))
    }

    // Where the items of [last], the last node a render rendered, start in its text (from [offset]).
    private fun listItemsOf(
      last: MarkdownASTNode?,
      rendered: TextRenderResult,
      offset: Int,
    ): ListItems = itemSignatures(last)?.let { listItemsOf(it, rendered, offset) } ?: ListItems.NONE

    private fun listItemsOf(
      signatures: LongArray,
      rendered: TextRenderResult,
      offset: Int,
    ): ListItems {
      if (rendered.listItemStarts.size != signatures.size) return ListItems.NONE
      return ListItems(
        signatures,
        IntArray(signatures.size) { rendered.listItemStarts[it] + offset },
        rendered.listItemTaskStarts,
        resumableStarts(rendered.styledText, rendered.listItemStarts),
      )
    }

    private fun nextRevision(): Long = revisions.incrementAndGet()

    // A tail starts where the text before it was resumable, so its own first start is too.
    private fun resumableStarts(
      text: CharSequence,
      starts: IntArray,
    ) = BooleanArray(starts.size) { starts[it] == 0 || (starts[it] <= text.length && text[starts[it] - 1] == '\n') }

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
