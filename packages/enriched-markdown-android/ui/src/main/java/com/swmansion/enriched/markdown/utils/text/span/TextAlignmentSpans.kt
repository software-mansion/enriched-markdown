package com.swmansion.enriched.markdown.utils.text.span

import android.text.SpannableStringBuilder
import android.text.TextDirectionHeuristics
import android.text.style.AlignmentSpan
import com.swmansion.enriched.markdown.styles.TextAlignment

/**
 * Applies [alignment] to [start]..[end].
 *
 * The layout only aligns relative to a paragraph's direction, so [TextAlignment.LEFT] and
 * [TextAlignment.RIGHT] are resolved per text paragraph, the way the text view resolves its
 * direction: from the first strong character, falling back to [layoutIsRtl] when there is none.
 */
fun applyTextAlignment(
  builder: SpannableStringBuilder,
  start: Int,
  end: Int,
  alignment: TextAlignment,
  layoutIsRtl: Boolean,
) {
  if (!alignment.isAbsolute) {
    val layoutAlignment = alignment.layoutAlignment(isRtl = false) ?: return
    builder.setSpan(AlignmentSpan.Standard(layoutAlignment), start, end, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
    return
  }

  val heuristic = if (layoutIsRtl) TextDirectionHeuristics.FIRSTSTRONG_RTL else TextDirectionHeuristics.FIRSTSTRONG_LTR
  var paragraphStart = start
  while (paragraphStart < end) {
    val newline = builder.indexOf('\n', paragraphStart)
    val paragraphEnd = if (newline in paragraphStart until end) newline + 1 else end
    val isRtl = heuristic.isRtl(builder, paragraphStart, paragraphEnd - paragraphStart)
    alignment.layoutAlignment(isRtl)?.let {
      builder.setSpan(AlignmentSpan.Standard(it), paragraphStart, paragraphEnd, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
    }
    paragraphStart = paragraphEnd
  }
}
