package com.swmansion.enriched.markdown.utils.text.view

import android.graphics.drawable.Drawable
import android.os.Build
import android.util.Log
import android.widget.TextView
import androidx.annotation.ColorInt
import androidx.core.graphics.drawable.DrawableCompat

private const val TAG = "TextSelectionColors"

private typealias HandleGetter = (TextView) -> Drawable?
private typealias HandleSetter = (TextView, Drawable) -> Unit

/**
 * Applies selection highlight and (where supported) handle tinting to a [TextView].
 *
 * Handle drawables are only tinted on API 29+ where the framework exposes getters;
 * on older versions the handle theme defaults remain unchanged.
 */
fun TextView.applySelectionColors(
  selectionColor: Int?,
  selectionHandleColor: Int?,
) {
  selectionColor?.let { highlightColor = it }
  selectionHandleColor?.let { applySelectionHandleTint(it) }
}

/**
 * Tints the selection handles of a [TextView] with [color], or clears a previously
 * applied tint when [color] is null (e.g. when the prop is removed).
 */
fun TextView.applySelectionHandleColor(
  @ColorInt color: Int?,
) {
  applySelectionHandleTint(color)
}

private fun TextView.applySelectionHandleTint(
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
      getter(this)
        ?.mutate()
        ?.also {
          if (color != null) DrawableCompat.setTint(it, color) else DrawableCompat.setTintList(it, null)
        }?.let { setter(this, it) }
    } catch (e: LinkageError) {
      Log.w(TAG, "Selection handle tint skipped: ${e.message}")
    }
  }
}
