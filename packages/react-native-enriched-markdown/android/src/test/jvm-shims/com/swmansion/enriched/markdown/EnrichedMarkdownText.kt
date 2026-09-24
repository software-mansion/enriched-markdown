package com.swmansion.enriched.markdown

import android.widget.TextView

/** Source and selection surface, without constructing an Android UI. */
class EnrichedMarkdownText : TextView() {
  var currentMarkdown: String = ""
}
