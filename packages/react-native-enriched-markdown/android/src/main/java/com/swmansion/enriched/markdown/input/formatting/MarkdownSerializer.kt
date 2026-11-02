package com.swmansion.enriched.markdown.input.formatting

import android.util.Log
import com.swmansion.enriched.markdown.input.model.BlockRange
import com.swmansion.enriched.markdown.input.model.BlockType
import com.swmansion.enriched.markdown.input.model.FormattingRange
import com.swmansion.enriched.markdown.input.model.StyleType

object MarkdownSerializer {
  private const val TAG = "MarkdownSerializer"

  // Zero-width space used by the editor to anchor an empty bullet line; it is an
  // internal editing aid and must never appear in serialized markdown.
  private const val ZWSP = "\u200B"

  /**
   * Single choke point for scrubbing the empty-line ZWSP anchor out of anything
   * bound for JS (serialized markdown here, plain text in `InputEventEmitter`).
   * Route new output paths through this rather than scattering `replace(ZWSP, "")`
   * calls, so the anchor can never leak because one path forgot to strip.
   */
  fun stripZwsp(text: String): String = text.replace(ZWSP, "")

  /**
   * Block-aware serialization: serializes inline styles exactly as the inline-only
   * overload, then prepends each line's block prefix. [blockPrefixProvider] is
   * asked, per block range, for the markdown line marker (e.g. `"# "`, `"- "`);
   * returning `""` leaves the line unprefixed. With empty [blockRanges] the output
   * is identical to the inline-only overload. Any ZWSP empty-line anchor is stripped
   * so an empty bullet still serializes to a bare `"- "` rather than `"- ​"`.
   */
  fun serialize(
    text: String,
    ranges: List<FormattingRange>,
    blockRanges: List<BlockRange>,
    blockPrefixProvider: (BlockRange) -> String,
  ): String = stripZwsp(serializeWithAnchors(text, ranges, blockRanges, blockPrefixProvider))

  private fun serializeWithAnchors(
    text: String,
    ranges: List<FormattingRange>,
    blockRanges: List<BlockRange>,
    blockPrefixProvider: (BlockRange) -> String,
  ): String {
    val inlineMarkdown = serialize(text, ranges)
    if (blockRanges.isEmpty()) return inlineMarkdown

    // Block prefixes attach per line. Inline serialization only inserts inline
    // delimiters (never newlines), so the serialized output has the same line
    // count as the plain text — we map a block's plain-text range to line indices
    // and prefix the corresponding serialized lines.
    val plainLines = text.split("\n")
    val markdownLines = inlineMarkdown.split("\n").toMutableList()

    // Inline delimiters never cross a newline, so the line partition is preserved.
    // If this ever breaks, prefixes would land on the wrong lines. Contract on
    // both platforms: log and fall back to inline-only output — a library must
    // not crash the host app over lost block prefixes.
    if (plainLines.size != markdownLines.size) {
      Log.e(TAG, "Block serialization line-count invariant violated: plain=${plainLines.size} markdown=${markdownLines.size}")
      return inlineMarkdown
    }

    // Plain-text character offset at the start of each line.
    val lineStartOffsets = IntArray(plainLines.size)
    var runningOffset = 0
    for (i in plainLines.indices) {
      lineStartOffsets[i] = runningOffset
      runningOffset += plainLines[i].length + 1 // +1 for the '\n' separator
    }

    for (blockRange in blockRanges) {
      val prefix = blockPrefixProvider(blockRange)
      if (prefix.isEmpty()) continue

      val isZeroLength = blockRange.length == 0
      val isListItem = blockRange.type in BlockType.LIST_ITEMS
      for (lineIndex in plainLines.indices) {
        val lineStart = lineStartOffsets[lineIndex]
        val lineEnd = lineStart + plainLines[lineIndex].length
        val overlaps = if (isZeroLength) lineStart == blockRange.start else lineEnd >= blockRange.start && lineStart < blockRange.end
        if (overlaps) {
          // A marker-only list line ("- " with no content) re-parses as a setext
          // underline for the previous line; emit an empty list line bare. An
          // empty "# " heading is valid ATX and keeps its prefix.
          if (isListItem && stripZwsp(plainLines[lineIndex]).isEmpty()) continue
          markdownLines[lineIndex] = prefix + markdownLines[lineIndex]
        }
      }
    }

    return markdownLines.joinToString("\n")
  }

  // A range md4c would not read back (underline over half a word) is dropped: losing
  // a style beats writing its delimiters into the text, where every reload keeps them.
  fun serialize(
    text: String,
    ranges: List<FormattingRange>,
  ): String {
    if (ranges.isEmpty()) return text

    var segments = trimmedSegments(text, ranges)
    while (true) {
      val events = boundaryEvents(segments)
      val unreadable = unflankedSegments(text, events)
      if (unreadable.isEmpty()) return writeMarkdown(text, events)
      segments = segments.filterNot { it in unreadable }
    }
  }

  private fun trimmedSegments(
    text: String,
    ranges: List<FormattingRange>,
  ): List<Segment> {
    val segments = ArrayList<Segment>(ranges.size)
    for (range in ranges) {
      var start = range.start.coerceIn(0, text.length)
      var end = range.end.coerceIn(0, text.length)

      // Trim leading/trailing whitespace so delimiters hug non-whitespace content
      while (start < end && text[start].isWhitespace()) start++
      while (end > start && text[end - 1].isWhitespace()) end--

      if (start < end) segments.add(Segment(start, end, range.type, range.url))
    }
    return segments
  }

  private fun boundaryEvents(segments: List<Segment>): List<BoundaryEvent> {
    val events = ArrayList<BoundaryEvent>(segments.size * 2)
    for (segment in segments) {
      events.add(BoundaryEvent(segment.start, true, segment))
      events.add(BoundaryEvent(segment.end, false, segment))
    }
    events.sortWith(BOUNDARY_COMPARATOR)
    return events
  }

  private fun writeMarkdown(
    text: String,
    events: List<BoundaryEvent>,
  ): String {
    val markdown = StringBuilder(text.length + events.size * 4)
    var lastPosition = 0

    for (event in events) {
      if (event.position > lastPosition) {
        markdown.append(text, lastPosition, event.position)
        lastPosition = event.position
      }

      if (event.isOpening) {
        markdown.append(openingDelimiter(event.type))
      } else {
        markdown.append(closingDelimiter(event.type, event.segment.url))
      }
    }

    if (lastPosition < text.length) {
      markdown.append(text, lastPosition, text.length)
    }

    return markdown.toString()
  }

  private fun unflankedSegments(
    text: String,
    events: List<BoundaryEvent>,
  ): Set<Segment> {
    val unflanked = HashSet<Segment>()
    for (i in events.indices) {
      val event = events[i]
      if (!isFlanking(event.type, event.isOpening, neighborBefore(text, events, i), neighborAfter(text, events, i))) {
        unflanked.add(event.segment)
      }
    }
    return unflanked
  }

  // A line's edge reads as whitespace (a block marker ends in a space), and another
  // delimiter as punctuation, except a "*" next to a "*", which joins its run.
  private enum class Neighbor { WHITESPACE, PUNCTUATION, WORD }

  // md4c's classes: CommonMark punctuation is Unicode P and S, so an emoji
  // counts as punctuation next to "**".
  private fun classify(codePoint: Int): Neighbor =
    when {
      Character.isWhitespace(codePoint) || Character.isSpaceChar(codePoint) -> Neighbor.WHITESPACE
      Character.getType(codePoint).toByte() in PUNCTUATION_TYPES -> Neighbor.PUNCTUATION
      else -> Neighbor.WORD
    }

  private val PUNCTUATION_TYPES =
    setOf(
      Character.CONNECTOR_PUNCTUATION,
      Character.DASH_PUNCTUATION,
      Character.START_PUNCTUATION,
      Character.END_PUNCTUATION,
      Character.INITIAL_QUOTE_PUNCTUATION,
      Character.FINAL_QUOTE_PUNCTUATION,
      Character.OTHER_PUNCTUATION,
      Character.MATH_SYMBOL,
      Character.CURRENCY_SYMBOL,
      Character.MODIFIER_SYMBOL,
      Character.OTHER_SYMBOL,
    )

  // "*" and "**" side by side are one delimiter run to md4c, flanked by what is
  // around the whole run: "***a***b" is bold italic "a".
  private fun isStarDelimiter(type: StyleType): Boolean = type == StyleType.BOLD || type == StyleType.ITALIC

  private fun neighborBefore(
    text: String,
    events: List<BoundaryEvent>,
    index: Int,
  ): Neighbor {
    val position = events[index].position
    val star = isStarDelimiter(events[index].type)
    var i = index - 1
    while (i >= 0 && events[i].position == position) {
      if (!star || !isStarDelimiter(events[i].type)) return Neighbor.PUNCTUATION
      i--
    }
    if (position == 0 || text[position - 1] == '\n') return Neighbor.WHITESPACE
    return classify(text.codePointBefore(position))
  }

  private fun neighborAfter(
    text: String,
    events: List<BoundaryEvent>,
    index: Int,
  ): Neighbor {
    val position = events[index].position
    val star = isStarDelimiter(events[index].type)
    var i = index + 1
    while (i < events.size && events[i].position == position) {
      if (!star || !isStarDelimiter(events[i].type)) return Neighbor.PUNCTUATION
      i++
    }
    if (position == text.length || text[position] == '\n') return Neighbor.WHITESPACE
    return classify(text.codePointAt(position))
  }

  // Measured against md4c, since "_" (underline) and "~~" are extensions:
  // "*"/"**" follow CommonMark flanking; "_"/"~~" don't work inside a word.
  private fun isFlanking(
    type: StyleType,
    isOpening: Boolean,
    before: Neighbor,
    after: Neighbor,
  ): Boolean {
    val inner = if (isOpening) after else before
    val outer = if (isOpening) before else after
    return when (type) {
      StyleType.BOLD, StyleType.ITALIC -> {
        inner != Neighbor.WHITESPACE && (inner != Neighbor.PUNCTUATION || outer != Neighbor.WORD)
      }

      StyleType.UNDERLINE, StyleType.STRIKETHROUGH -> {
        inner != Neighbor.WHITESPACE && outer != Neighbor.WORD
      }

      StyleType.LINK, StyleType.SPOILER -> {
        true
      }
    }
  }

  private fun openingDelimiter(type: StyleType): String =
    when (type) {
      StyleType.BOLD -> "**"
      StyleType.ITALIC -> "*"
      StyleType.UNDERLINE -> "_"
      StyleType.STRIKETHROUGH -> "~~"
      StyleType.LINK -> "["
      StyleType.SPOILER -> "||"
    }

  private fun closingDelimiter(
    type: StyleType,
    url: String?,
  ): String =
    when (type) {
      StyleType.BOLD -> "**"
      StyleType.ITALIC -> "*"
      StyleType.UNDERLINE -> "_"
      StyleType.STRIKETHROUGH -> "~~"
      StyleType.LINK -> "](${url ?: ""})"
      StyleType.SPOILER -> "||"
    }

  // Lower value = outermost wrapper. Font styles wrap around structural styles (link).
  private fun nestingPriority(type: StyleType): Int =
    when (type) {
      StyleType.ITALIC -> 0
      StyleType.BOLD -> 1
      StyleType.UNDERLINE -> 2
      StyleType.STRIKETHROUGH -> 3
      StyleType.SPOILER -> 4
      StyleType.LINK -> 5
    }

  // Identity, not value, equality: two equal ranges are still two segments to drop.
  private class Segment(
    val start: Int,
    val end: Int,
    val type: StyleType,
    val url: String?,
  )

  private class BoundaryEvent(
    val position: Int,
    val isOpening: Boolean,
    val segment: Segment,
  ) {
    val type: StyleType get() = segment.type
  }

  private val BOUNDARY_COMPARATOR =
    Comparator<BoundaryEvent> { a, b ->
      if (a.position != b.position) {
        return@Comparator a.position - b.position
      }
      // Closing events before opening events at the same position
      if (a.isOpening != b.isOpening) {
        return@Comparator if (a.isOpening) 1 else -1
      }
      // Among openings: outer first (lower priority emitted first)
      // Among closings: inner first (higher priority emitted first) — LIFO order
      if (a.isOpening) {
        nestingPriority(a.type) - nestingPriority(b.type)
      } else {
        nestingPriority(b.type) - nestingPriority(a.type)
      }
    }
}
