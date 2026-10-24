package com.swmansion.enriched.markdown.compose.patches

import androidx.compose.runtime.Immutable
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.styles.SubscriptStyle

@Immutable
internal data class SubscriptStylePatch(
  val fontScale: Float? = null,
  val baselineOffsetScale: Float? = null,
) {
  fun apply(base: SubscriptStyle): SubscriptStyle =
    base.copy(
      fontScale = fontScale ?: base.fontScale,
      baselineOffsetScale = baselineOffsetScale ?: base.baselineOffsetScale,
    )
}

@MarkdownStyleDsl
class SubscriptStyleScope internal constructor() {
  var fontScale: Float? = null
  var baselineOffsetScale: Float? = null

  internal fun toPatch(): SubscriptStylePatch =
    SubscriptStylePatch(
      fontScale = fontScale,
      baselineOffsetScale = baselineOffsetScale,
    )

  internal companion object {
    fun merge(
      existing: SubscriptStylePatch?,
      block: SubscriptStyleScope.() -> Unit,
    ): SubscriptStylePatch {
      val scope =
        SubscriptStyleScope().apply {
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
