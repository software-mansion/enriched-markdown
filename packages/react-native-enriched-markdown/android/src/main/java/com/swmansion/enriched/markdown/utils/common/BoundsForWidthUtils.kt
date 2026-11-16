package com.swmansion.enriched.markdown.utils.common

import android.os.Build
import android.text.StaticLayout
import android.widget.TextView

/**
 * Turns on bounds-based line widths for the markdown text views and for the
 * StaticLayouts that measure them.
 *
 * TextView enables this on its own only for apps targeting API 35+, while the measure
 * pass can't see the view, so both sides are pinned here. A line ending on an overhanging
 * glyph, like italic, is wider than its advances. If the two disagree, the view comes out
 * a pixel or two narrow and wraps a line it has no room for.
 */
object BoundsForWidthUtils {
  fun applyTo(view: TextView) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
      view.useBoundsForWidth = true
    }
  }

  fun applyTo(builder: StaticLayout.Builder) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
      builder.setUseBoundsForWidth(true)
    }
  }
}
