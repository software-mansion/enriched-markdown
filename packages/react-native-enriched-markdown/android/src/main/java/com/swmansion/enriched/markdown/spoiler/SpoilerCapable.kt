package com.swmansion.enriched.markdown.spoiler

import android.view.View
import android.view.ViewGroup

/** A text view that draws spoiler overlays, so taps on its concealed spoilers reveal them. */
interface SpoilerCapable {
  val spoilerOverlayDrawer: SpoilerOverlayDrawer?

  /** The `spoilerOverlay` prop this view conceals its spoilers with. */
  var spoilerOverlay: SpoilerOverlayMode
}

/** Runs [action] on every [SpoilerCapable] view under [root], nested containers and table cells included. */
internal fun forEachSpoilerCapableDescendant(
  root: View,
  action: (SpoilerCapable) -> Unit,
) {
  if (root is SpoilerCapable) action(root)
  if (root is ViewGroup) {
    for (index in 0 until root.childCount) forEachSpoilerCapableDescendant(root.getChildAt(index), action)
  }
}
