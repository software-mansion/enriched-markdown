package com.swmansion.enriched.markdown.compose.patches

import androidx.compose.runtime.Immutable
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.styles.SuperscriptStyle

@Immutable
internal data class SuperscriptStylePatch(
  val fontScale: Float? = null,
  val baselineOffsetScale: Float? = null,
) {
  fun apply(base: SuperscriptStyle): SuperscriptStyle =
    base.copy(
      fontScale = fontScale ?: base.fontScale,
      baselineOffsetScale = baselineOffsetScale ?: base.baselineOffsetScale,
    )
}

@MarkdownStyleDsl
class SuperscriptStyleScope internal constructor() {
  var fontScale: Float? = null
  var baselineOffsetScale: Float? = null

  internal fun toPatch(): SuperscriptStylePatch =
    SuperscriptStylePatch(
      fontScale = fontScale,
      baselineOffsetScale = baselineOffsetScale,
    )

  internal companion object {
    fun merge(
      existing: SuperscriptStylePatch?,
      block: SuperscriptStyleScope.() -> Unit,
    ): SuperscriptStylePatch {
      val scope =
        SuperscriptStyleScope().apply {
          if (existing != null) {
            fontScale = existing.fontScale
            baselineOffsetScale = existing.baselineOffsetScale
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}
