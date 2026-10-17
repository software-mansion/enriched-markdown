package com.swmansion.enriched.markdown.slots

import android.content.Context
import com.facebook.react.views.view.ReactViewGroup

/** One React replacement for a block; its content is ordinary Fabric children. */
class EnrichedMarkdownBlockSlotView(
  context: Context,
) : ReactViewGroup(context) {
  var slotId: String = ""
}
