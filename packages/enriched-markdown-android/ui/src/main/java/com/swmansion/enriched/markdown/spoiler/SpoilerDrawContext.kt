package com.swmansion.enriched.markdown.spoiler

import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.text.Layout
import android.text.Spanned
import android.view.View
import android.widget.TextView
import com.swmansion.enriched.markdown.spans.SpoilerSpan

class SpoilerDrawContext(
  val textView: TextView,
  val layout: Layout,
  val text: Spanned,
  val spans: Array<SpoilerSpan>,
  val paddingLeft: Float,
  val paddingTop: Float,
  val backgroundColor: Int,
) {
  companion object {
    fun resolveBackgroundColor(
      textView: TextView,
      styledBackgroundColor: Int?,
    ): Int {
      if (styledBackgroundColor != null && Color.alpha(styledBackgroundColor) > 0) {
        return styledBackgroundColor
      }

      var view: View? = textView
      while (view != null) {
        val color = (view.background as? ColorDrawable)?.color
        if (color != null && Color.alpha(color) > 0) return color
        view = view.parent as? View
      }
      return Color.WHITE
    }
  }
}
