package android.text

/** The range-query surface used by MarkdownExtractor, with Android span edges. */
interface Spannable : CharSequence {
  fun <T> getSpans(
    start: Int,
    end: Int,
    type: Class<T>,
  ): Array<T>

  fun nextSpanTransition(
    start: Int,
    limit: Int,
    type: Class<*>,
  ): Int
}

class TestSpannable(
  private val content: String,
) : Spannable {
  private data class Range(
    val value: Any,
    val start: Int,
    val end: Int,
  )

  private val ranges = mutableListOf<Range>()

  fun span(
    value: Any,
    start: Int,
    end: Int,
  ): TestSpannable {
    require(start >= 0 && end <= length && start < end)
    ranges.add(Range(value, start, end))
    return this
  }

  override val length: Int get() = content.length

  override fun get(index: Int): Char = content[index]

  override fun subSequence(
    startIndex: Int,
    endIndex: Int,
  ): CharSequence = content.subSequence(startIndex, endIndex)

  override fun toString(): String = content

  override fun <T> getSpans(
    start: Int,
    end: Int,
    type: Class<T>,
  ): Array<T> {
    val matching = ranges.filter { type.isInstance(it.value) && it.start < end && it.end > start }

    @Suppress("UNCHECKED_CAST")
    val result =
      java.lang.reflect.Array
        .newInstance(type, matching.size) as Array<T>
    matching.forEachIndexed { index, range -> result[index] = type.cast(range.value) }
    return result
  }

  override fun nextSpanTransition(
    start: Int,
    limit: Int,
    type: Class<*>,
  ): Int =
    ranges
      .filter { type.isInstance(it.value) }
      .flatMap { listOf(it.start, it.end) }
      .filter { it > start && it < limit }
      .minOrNull() ?: limit
}
