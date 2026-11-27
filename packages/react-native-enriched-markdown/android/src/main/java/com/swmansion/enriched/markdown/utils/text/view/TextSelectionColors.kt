package com.swmansion.enriched.markdown.utils.text.view

import android.graphics.BlendMode
import android.graphics.BlendModeColorFilter
import android.graphics.drawable.Drawable
import android.os.Build
import android.util.Log
import android.widget.TextView
import androidx.annotation.ColorInt

private const val TAG = "TextSelectionColors"

private typealias HandleGetter = (TextView) -> Drawable?
private typealias HandleSetter = (TextView, Drawable) -> Unit

/**
 * Applies selection highlight and (where supported) handle coloring to a [TextView].
 *
 * Handle drawables are only colored on API 29+ where the framework exposes getters;
 * on older versions the handle theme defaults remain unchanged.
 */
fun TextView.applySelectionColors(
  selectionColor: Int?,
  selectionHandleColor: Int?,
) {
  selectionColor?.let { highlightColor = it }
  selectionHandleColor?.let { applySelectionHandleColor(it) }
}

/**
 * Colors the left, right and insertion handles with [color] on API 29+. A null [color]
 * clears it, bringing back the theme's handle color, which is the drawables' own tint.
 */
fun TextView.applySelectionHandleColor(
  @ColorInt color: Int?,
) {
  if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return

  val handles: List<Pair<HandleGetter, HandleSetter>> =
    listOf(
      TextView::getTextSelectHandleLeft to { tv, d -> tv.setTextSelectHandleLeft(d) },
      TextView::getTextSelectHandle to { tv, d -> tv.setTextSelectHandle(d) },
      TextView::getTextSelectHandleRight to { tv, d -> tv.setTextSelectHandleRight(d) },
    )

  handles.forEach { (getter, setter) ->
    try {
      val handle = getter(this)?.mutate() ?: return@forEach
      if (color != null) {
        handle.colorFilter = BlendModeColorFilter(color, BlendMode.SRC_IN)
      } else {
        handle.clearColorFilter()
      }
      setter(this, handle)
    } catch (e: LinkageError) {
      Log.w(TAG, "Selection handle color skipped: ${e.message}")
    }
  }
}
