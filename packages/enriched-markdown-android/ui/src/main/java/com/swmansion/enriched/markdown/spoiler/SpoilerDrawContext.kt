package com.swmansion.enriched.markdown.spoiler

import android.graphics.Color
import android.graphics.Paint
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
  val fontMetrics: Paint.FontMetrics,
  val backgroundColor: Int,
) {
  companion object {
    /**
     * The color the particle overlay paints over the concealed text before fading it out, so it
     * has to match whatever the text sits on.
     *
     * The styled value wins when it is set. Otherwise the view tree is walked upwards for the
     * first opaque [ColorDrawable] background, and white stands in when there is none. Inference
     * misses the common Compose case — a background declared as a `Modifier` on the `AndroidView`
     * wrapper is not a view background — which is exactly why
     * [com.swmansion.enriched.markdown.styles.SpoilerStyle.backgroundColor] exists.
     */
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
