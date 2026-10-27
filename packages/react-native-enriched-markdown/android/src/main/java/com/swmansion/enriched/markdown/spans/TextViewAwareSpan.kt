package com.swmansion.enriched.markdown.spans

import android.text.Spanned
import android.widget.TextView

/** A span that needs the view showing its text, e.g. for its width or layout. */
interface TextViewAwareSpan {
  /** Called with the view [registerWithSpans] gave the span's text to. */
  fun registerTextView(view: TextView)
}

/** Registers this view with every [TextViewAwareSpan] in [text]. */
internal fun TextView.registerWithSpans(text: CharSequence?) {
  if (text !is Spanned) return
  for (span in text.getSpans(0, text.length, TextViewAwareSpan::class.java)) {
    span.registerTextView(this)
  }
}
