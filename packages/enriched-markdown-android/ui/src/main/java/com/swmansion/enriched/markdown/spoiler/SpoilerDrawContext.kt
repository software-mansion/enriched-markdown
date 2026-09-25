package com.swmansion.enriched.markdown.spoiler

import android.text.Layout
import android.text.Spanned
import android.widget.TextView
import com.swmansion.enriched.markdown.spans.SpoilerSpan

class SpoilerDrawContext(
  val textView: TextView,
  val layout: Layout,
  val text: Spanned,
  val spans: Array<SpoilerSpan>,
  val paddingLeft: Float,
  val paddingTop: Float,
)
