package com.swmansion.enriched.markdown.input.editing

import android.text.Spannable
import com.swmansion.enriched.markdown.input.autolink.AutoLinkDetector
import com.swmansion.enriched.markdown.input.formatting.FormattingStore
import com.swmansion.enriched.markdown.input.model.FormattingRange
import com.swmansion.enriched.markdown.input.model.StyleType

class LinkCoordinator(
  private val formattingStore: FormattingStore,
  private val autoLinkDetector: AutoLinkDetector,
) {
  fun sanitizeUrl(url: String): String =
    url
      .replace("(", "%28")
      .replace(")", "%29")

  fun linkAtPosition(position: Int): FormattingRange? = formattingStore.rangeOfType(StyleType.LINK, position)

  fun setLinkForRange(
    url: String,
    start: Int,
    end: Int,
    editable: Spannable?,
  ) {
    if (start == end) return
    if (editable != null) {
      autoLinkDetector.clearAutoLinkInRange(editable, start, end)
    }
    formattingStore.addRange(FormattingRange(StyleType.LINK, start, end, url))
  }

  fun addLink(
    url: String,
    start: Int,
    end: Int,
    editable: Spannable?,
  ) {
    if (start >= end) return
    if (editable != null) {
      autoLinkDetector.clearAutoLinkInRange(editable, start, end)
    }
    formattingStore.addRange(FormattingRange(StyleType.LINK, start, end, sanitizeUrl(url)))
  }

  fun addLinkDirect(
    url: String,
    start: Int,
    end: Int,
  ) {
    if (start >= end) return
    formattingStore.addRange(FormattingRange(StyleType.LINK, start, end, url))
  }

  fun removeLink(position: Int): Boolean {
    val linkRange = formattingStore.rangeOfType(StyleType.LINK, position) ?: return false
    formattingStore.removeRange(linkRange)
    return true
  }

  /**
   * Finds the link containing `position - 1` and returns its range for deletion.
   * Returns null if no link is found.
   */
  fun linkRangeForDeletion(position: Int): FormattingRange? {
    if (position <= 0) return null
    return formattingStore.rangeOfType(StyleType.LINK, position - 1)
  }
}
