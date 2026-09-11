package com.swmansion.enriched.markdown.spans

import android.graphics.Paint
import android.text.style.LineHeightSpan

/**
 * Adds bottom margin to a block element (paragraphs/headings) using LineHeightSpan.
 *
 * For spacer lines (single newline), sets the line height to exactly marginBottom.
 * For regular lines, adds marginBottom only at paragraph boundaries to preserve lineHeight.
 *
 * @param marginBottom The margin in pixels to add below the block (0 = no margin)
 */
class MarginBottomSpan(
  val marginBottom: Float,
) : LineHeightSpan {
  override fun chooseHeight(
    text: CharSequence,
    start: Int,
    end: Int,
    spanstartv: Int,
    lineHeight: Int,
    fm: Paint.FontMetricsInt,
  ) {
    // Only process lines that end with a newline
    if (end <= start || text[end - 1] != '\n') {
      return
    }

    val marginPixels = marginBottom.toInt()

    // Handle spacer lines (single newline character)
    if (end - start == 1 && text[start] == '\n') {
      if (hasContentAfter(text, end)) {
        // Set line height to exactly marginBottom for spacer lines
        fm.top = 0
        fm.ascent = 0
        fm.descent = marginPixels
        fm.bottom = marginPixels
      } else {
        // No content after - collapse the spacer line to zero height
        fm.top = 0
        fm.ascent = 0
        fm.descent = 0
        fm.bottom = 0
      }
      return
    }

    // For regular lines, add spacing only if there's content after
    if (hasContentAfter(text, end)) {
      fm.descent += marginPixels
      fm.bottom += marginPixels
    }
  }

  /**
   * Checks if there's non-newline content after the given position.
   * Used to determine if spacing should be applied (between items) or skipped (after last item).
   *
   * Spacer lines stack, so the whole run of newlines has to be skipped rather than a single one:
   * a block's bottom margin can be followed by the next block's top margin, its padding spacer and
   * its admonition header spacer before any glyph. Stopping after one newline read those spacers as
   * the end of the document and collapsed the margin away.
   */
  private fun hasContentAfter(
    text: CharSequence,
    pos: Int,
  ): Boolean {
    var next = pos
    while (next < text.length && text[next] == '\n') {
      next++
    }
    return next < text.length
  }
}
