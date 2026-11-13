package com.swmansion.enriched.markdown.input.formatting

import com.swmansion.enriched.markdown.input.model.FormattingRange
import com.swmansion.enriched.markdown.input.model.StyleType
import java.util.Collections

class FormattingStore {
  private val ranges = mutableListOf<FormattingRange>()

  val allRanges: List<FormattingRange> get() = Collections.unmodifiableList(ranges)

  fun setRanges(newRanges: List<FormattingRange>) {
    ranges.clear()
    ranges.addAll(newRanges.sortedBy { it.start })
  }

  fun clearAll() {
    ranges.clear()
  }

  fun rangeOfType(
    type: StyleType,
    containingPosition: Int,
  ): FormattingRange? = ranges.firstOrNull { it.type == type && containingPosition >= it.start && containingPosition < it.end }

  fun isStyleActive(
    type: StyleType,
    position: Int,
  ): Boolean = rangeOfType(type, position) != null

  fun isStyleActiveInRange(
    type: StyleType,
    start: Int,
    end: Int,
  ): Boolean = ranges.any { it.type == type && it.start < end && it.end > start }

  /**
   * Snaps a selection so it never partially overlaps an atomic link: a partial selection expands to
   * the whole link, a caret inside a link moves to its end. Returns the adjusted (start, end) or null.
   */
  fun selectionAdjustedForAtomicLinks(
    start: Int,
    end: Int,
  ): Pair<Int, Int>? {
    if (start != end) {
      var newStart = start
      var newEnd = end
      rangeOfType(StyleType.LINK, newStart)?.let { newStart = minOf(newStart, it.start) }
      if (newEnd > 0) rangeOfType(StyleType.LINK, newEnd - 1)?.let { newEnd = maxOf(newEnd, it.end) }
      return if (newStart != start || newEnd != end) Pair(newStart, newEnd) else null
    }
    val link = rangeOfType(StyleType.LINK, start)
    return if (link != null && start > link.start && start < link.end) Pair(link.end, link.end) else null
  }

  enum class ToggleResult {
    /** The style was active and has been removed (or is active at the caret). */
    WAS_ACTIVE,

    /** The style was inactive and has been added (or is inactive at the caret). */
    WAS_INACTIVE,
  }

  /**
   * Toggles [type] on the range `[start, end)`. For a selection (`start < end`),
   * removes the style when active at `start`, otherwise strips [conflictingStyles]
   * and adds it. For a caret (`start == end`), reports the current state without
   * mutating — the caller manages pending-style bookkeeping.
   */
  fun toggleStyle(
    type: StyleType,
    start: Int,
    end: Int,
    conflictingStyles: Set<StyleType>,
  ): ToggleResult {
    val isActive = isStyleActive(type, start)
    if (start < end) {
      if (isActive) {
        removeType(type, start, end)
      } else {
        addStyle(type, start, end, conflictingStyles)
      }
    }
    return if (isActive) ToggleResult.WAS_ACTIVE else ToggleResult.WAS_INACTIVE
  }

  /** Strips [conflictingStyles] from `[start, end)` and adds [type] over it. */
  fun addStyle(
    type: StyleType,
    start: Int,
    end: Int,
    conflictingStyles: Set<StyleType>,
  ) {
    for (conflict in conflictingStyles) {
      removeType(conflict, start, end)
    }
    addRange(FormattingRange(type, start, end))
  }

  /**
   * The range toggling [type] over `[start, end)` should cover, or null when it is `[start, end)`
   * itself. md4c ignores a `_` between two word characters ("Intra-word underscore doesn't have
   * special meaning"), so an underline that starts or ends inside a word would be written as
   * markdown that reads back with a literal `_`. Instead the toggle, on or off, grows to the word's
   * edges:
   * - a caret touching a word takes the whole word (at the word's edge the toggle only pends;
   *   [growToWholeWords] makes letters typed there join the word);
   * - a selection edge inside a word moves out to the word's edge.
   * A caret with no word on either side stays a caret. Another style's delimiter can stop the growth
   * inside a word (see [UnderlineSeparators]).
   */
  fun wholeWordRange(
    type: StyleType,
    text: CharSequence,
    start: Int,
    end: Int,
  ): Pair<Int, Int>? {
    if (type != StyleType.UNDERLINE) return null
    if (start == end && !isWordBefore(text, start) && !isWordAt(text, start)) return null
    return grownToWords(text, start, end, start == end, UnderlineSeparators(ranges))
  }

  /** [grows] makes both edges grow, as a caret does; otherwise an edge next to whitespace inside the range stays put. */
  private fun grownToWords(
    text: CharSequence,
    start: Int,
    end: Int,
    grows: Boolean,
    separators: UnderlineSeparators,
  ): Pair<Int, Int>? {
    var newStart = start
    if (grows || !isWhitespaceAt(text, start)) {
      while (isWordBefore(text, newStart) && !separators.start(newStart)) {
        newStart -= Character.charCount(Character.codePointBefore(text, newStart))
      }
    }
    var newEnd = end
    if (grows || !isWhitespaceBefore(text, end)) {
      while (isWordAt(text, newEnd) && !separators.end(newEnd)) {
        newEnd += Character.charCount(Character.codePointAt(text, newEnd))
      }
    }
    return if (newStart != start || newEnd != end) Pair(newStart, newEnd) else null
  }

  /**
   * Grows the underlines touching the edited span `[editStart, editEnd)` (in the text after the
   * edit; touching it at an edge counts) when the edit left one starting or ending inside a word, to
   * that word's edges, by the selection rule of [wholeWordRange]: letters typed or pasted right
   * before or after an underlined word join it, and so does the word a deletion glued to it.
   * Underlines away from the edit are left as they are.
   */
  fun growToWholeWords(
    text: CharSequence,
    editStart: Int,
    editEnd: Int,
  ) {
    val touching =
      ranges.filter {
        it.type == StyleType.UNDERLINE && it.start <= editEnd && it.end >= editStart && it.start < it.end && it.end <= text.length
      }
    if (touching.isEmpty()) return
    val separators = UnderlineSeparators(ranges)
    for (range in touching) {
      val (start, end) = grownToWords(text, range.start, range.end, false, separators) ?: continue
      addRange(FormattingRange(range.type, start, end))
    }
  }

  /**
   * Whether the store gives [type] to text typed at a caret at [position]: a range covers it or, for
   * underline, an underlined word ends there, since [growToWholeWords] pulls letters typed right
   * after the word into its underline. A style starting there doesn't stop them (see
   * [UnderlineSeparators]): typing at its start moves it along.
   */
  fun isStyleActiveAtCaret(
    type: StyleType,
    text: CharSequence,
    position: Int,
  ): Boolean {
    if (isStyleActive(type, position)) return true
    if (type != StyleType.UNDERLINE || !isWordBefore(text, position)) return false
    return ranges.any { it.type == type && it.end == position }
  }

  /**
   * Where another style's delimiter, written between an underline's `_` and the letter beside it,
   * already makes the `_` readable, so the underline needs no growth there (every delimiter
   * character is punctuation to md4c). Growth follows one rule: it never changes an underline whose
   * markdown reads back, along with the styles beside it, and fixes one that doesn't. So it follows
   * where [MarkdownSerializer] writes delimiters:
   * - At one position closings come before openings, so a style ending where an underline starts,
   *   or starting where one ends, separates them: `*foo*_bar_`, `_foo_**bar**`.
   * - A style starting (or ending) along with the underline separates only when it nests outside
   *   it, and only a link or spoiler would, as on web. Here links and spoilers nest inside
   *   (`foo_[bar](u)_`), so none does. Italic and bold nest outside, but between a letter and `_`
   *   md4c reads `*` and `**` as text (`foo**_bar_**`), so the underline takes the whole word and
   *   both read back: `_foo**bar**_`.
   * The ranges are collected once per call, and no underline is among them, so they stay valid
   * while the underlines grow. A style md4c can't read at its other edge, as a strikethrough
   * starting inside a word, still counts.
   */
  private class UnderlineSeparators(
    ranges: List<FormattingRange>,
  ) {
    private val starts = HashSet<Int>()
    private val ends = HashSet<Int>()

    init {
      for (range in ranges) {
        if (range.type == StyleType.UNDERLINE || range.start >= range.end) continue
        starts.add(range.start)
        ends.add(range.end)
      }
    }

    /** An underline starting at [position] needs no growth before it. */
    fun start(position: Int): Boolean = position in ends

    /** An underline ending at [position] needs no growth after it. */
    fun end(position: Int): Boolean = position in starts
  }

  /**
   * Returns true when toggling [type] ON at [position] should be refused
   * because one of the [blockingStyles] is currently active there.
   * Toggling OFF (the style is already active) is never blocked.
   */
  fun isToggleBlocked(
    type: StyleType,
    position: Int,
    blockingStyles: Set<StyleType>,
  ): Boolean {
    if (blockingStyles.isEmpty()) return false
    if (isStyleActive(type, position)) return false
    return blockingStyles.any { isStyleActive(it, position) }
  }

  fun addRange(newRange: FormattingRange) {
    var mergedStart = newRange.start
    var mergedEnd = newRange.end
    val mergeIndexes = mutableListOf<Int>()

    for ((idx, existing) in ranges.withIndex()) {
      if (existing.type != newRange.type) continue
      if (existing.start <= mergedEnd && existing.end >= mergedStart) {
        mergedStart = minOf(mergedStart, existing.start)
        mergedEnd = maxOf(mergedEnd, existing.end)
        mergeIndexes.add(idx)
      }
    }

    for (idx in mergeIndexes.reversed()) {
      ranges.removeAt(idx)
    }

    val merged = FormattingRange(newRange.type, mergedStart, mergedEnd, newRange.url)
    val insertAt = sortedInsertionIndex(ranges, mergedStart)
    ranges.add(insertAt, merged)
  }

  fun removeType(
    type: StyleType,
    start: Int,
    end: Int,
  ) {
    val remainders = mutableListOf<FormattingRange>()
    val indexesToRemove = mutableListOf<Int>()

    for ((idx, existing) in ranges.withIndex()) {
      if (existing.type != type) continue
      if (existing.end <= start || existing.start >= end) continue

      indexesToRemove.add(idx)

      if (existing.start < start) {
        remainders.add(FormattingRange(type, existing.start, start, existing.url))
      }
      if (existing.end > end) {
        remainders.add(FormattingRange(type, end, existing.end, existing.url))
      }
    }

    for (idx in indexesToRemove.reversed()) {
      ranges.removeAt(idx)
    }

    // Remainders are fragments of a just-removed range and cannot overlap others.
    for (remainder in remainders) {
      val insertAt = sortedInsertionIndex(ranges, remainder.start)
      ranges.add(insertAt, remainder)
    }
  }

  fun removeRange(range: FormattingRange) {
    ranges.remove(range)
  }

  /** Shifts/clips formatting ranges to follow a text edit. See [RangeEditAdjustment]. */
  fun adjustForEdit(
    editLocation: Int,
    deletedLength: Int,
    insertedLength: Int,
  ) {
    RangeEditAdjustment.adjustForEdit(
      ranges,
      editLocation,
      deletedLength,
      insertedLength,
      inheritsReplacementAtStart = { it.type != StyleType.LINK },
    )
    coalesceAdjacentSameTypeRanges()
  }

  /**
   * Merge same-type (and same-url) ranges left adjacent or overlapping by an
   * edit — e.g. deleting the space in "**foo** **bar**" leaves two touching
   * bold ranges that would serialize as "**foo****bar**". [addRange] keeps
   * this invariant on insert; the edit path must too.
   */
  private fun coalesceAdjacentSameTypeRanges() {
    var idx = 0
    while (idx < ranges.size) {
      val current = ranges[idx]
      var next = idx + 1
      while (next < ranges.size && ranges[next].start <= current.end) {
        val candidate = ranges[next]
        if (candidate.type == current.type && candidate.url == current.url) {
          current.end = maxOf(current.end, candidate.end)
          ranges.removeAt(next)
        } else {
          next++
        }
      }
      idx++
    }
  }
}

// Java's isWhitespace leaves out no-break spaces (U+00A0, U+2007, U+202F), which md4c and the iOS
// and web inputs treat as whitespace, so space separators count too.
private fun isWhitespaceCodePoint(codePoint: Int): Boolean = Character.isWhitespace(codePoint) || Character.isSpaceChar(codePoint)

// md4c's character classes: a word character is neither whitespace nor Unicode punctuation (P) or
// symbol (S), so an emoji counts as punctuation.
private fun isWordCodePoint(codePoint: Int): Boolean {
  if (isWhitespaceCodePoint(codePoint)) return false
  return when (Character.getType(codePoint).toByte()) {
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
    -> false

    else -> true
  }
}

private fun isWordAt(
  text: CharSequence,
  position: Int,
): Boolean = position < text.length && isWordCodePoint(Character.codePointAt(text, position))

private fun isWordBefore(
  text: CharSequence,
  position: Int,
): Boolean = position > 0 && isWordCodePoint(Character.codePointBefore(text, position))

private fun isWhitespaceAt(
  text: CharSequence,
  position: Int,
): Boolean = position < text.length && isWhitespaceCodePoint(Character.codePointAt(text, position))

private fun isWhitespaceBefore(
  text: CharSequence,
  position: Int,
): Boolean = position > 0 && isWhitespaceCodePoint(Character.codePointBefore(text, position))
