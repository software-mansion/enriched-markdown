package com.swmansion.enriched.markdown.utils.text.span

import android.text.Spanned
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.spans.LinkPillSpan

/**
 * Primes every span whose size depends on the layout width (pills, images). Call it
 * before building any layout over [text]. Pass false for [includeBlockImages] when [widthPx]
 * is only an upper bound, not the width the text will be laid out at: a block image fills
 * the width it is given, while an inline image (a failure chip) is only capped by it.
 *
 * Returns true when a span's size changed, i.e. an existing layout is stale.
 */
fun prepareWidthAwareSpans(
  text: CharSequence?,
  widthPx: Int,
  includeBlockImages: Boolean = true,
): Boolean {
  val spanned = text as? Spanned ?: return false
  // widthPx == 1 is the coerceAtLeast(1) fallback for a not-yet-measured view. Priming
  // with it would squeeze pills on screen to a sliver until the next real measure.
  if (widthPx <= 1) return false
  var changed = LinkPillSpan.prepareForMeasurement(spanned, widthPx)
  spanned
    .getSpans(0, spanned.length, ImageSpan::class.java)
    .filter { includeBlockImages || it.isInline }
    .forEach { changed = it.prepareForMeasurement(spanned, widthPx) || changed }
  return changed
}
