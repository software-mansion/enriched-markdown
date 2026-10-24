package com.swmansion.enriched.markdown.compose.patches

import androidx.compose.runtime.Immutable
import androidx.compose.ui.unit.Dp
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.StyleUnits
import com.swmansion.enriched.markdown.styles.ImageStyle

@Immutable
internal data class ImageStylePatch(
  val height: Dp? = null,
  val cornerRadius: Dp? = null,
  val marginTop: Dp? = null,
  val marginBottom: Dp? = null,
) {
  fun apply(
    base: ImageStyle,
    units: StyleUnits,
  ): ImageStyle =
    base.copy(
      height = height?.let(units::dp) ?: base.height,
      borderRadius = cornerRadius?.let(units::dp) ?: base.borderRadius,
      marginTop = marginTop?.let(units::dp) ?: base.marginTop,
      marginBottom = marginBottom?.let(units::dp) ?: base.marginBottom,
    )
}

@MarkdownStyleDsl
class ImageStyleScope internal constructor() {
  var height: Dp? = null
  var cornerRadius: Dp? = null

  var marginTop: Dp? = null
  var marginBottom: Dp? = null

  internal fun toPatch(): ImageStylePatch =
    ImageStylePatch(
      height = height,
      cornerRadius = cornerRadius,
      marginTop = marginTop,
      marginBottom = marginBottom,
    )

  internal companion object {
    fun merge(
      existing: ImageStylePatch?,
      block: ImageStyleScope.() -> Unit,
    ): ImageStylePatch {
      val scope =
        ImageStyleScope().apply {
          if (existing != null) {
            height = existing.height
            cornerRadius = existing.cornerRadius
            marginTop = existing.marginTop
            marginBottom = existing.marginBottom
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}
