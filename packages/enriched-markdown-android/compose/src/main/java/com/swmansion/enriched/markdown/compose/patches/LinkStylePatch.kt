package com.swmansion.enriched.markdown.compose.patches

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextDecoration
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.FontFamilyResolver
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.compose.style.StyleUnits
import com.swmansion.enriched.markdown.styles.LinkStyle

@Immutable
internal data class LinkStylePatch(
  val fontFamily: FontFamily? = null,
  val color: Color? = null,
  val textDecoration: TextDecoration? = null,
  val backgroundColor: Color? = null,
) {
  fun apply(
    base: LinkStyle,
    resolveContext: StyleResolveContext,
    units: StyleUnits,
  ): LinkStyle =
    base.copy(
      fontFamily = fontFamily?.let { FontFamilyResolver.resolve(it, resolveContext) } ?: base.fontFamily,
      color = color?.let(units::color) ?: base.color,
      underline = textDecoration?.contains(TextDecoration.Underline) ?: base.underline,
      strikethrough = textDecoration?.contains(TextDecoration.LineThrough) ?: base.strikethrough,
      backgroundColor = backgroundColor?.let(units::color) ?: base.backgroundColor,
    )
}

@MarkdownStyleDsl
class LinkStyleScope internal constructor() {
  var fontFamily: FontFamily? = null
  var color: Color? = null
  var textDecoration: TextDecoration? = null
  var backgroundColor: Color? = null

  internal fun toPatch(): LinkStylePatch =
    LinkStylePatch(
      fontFamily = fontFamily,
      color = color,
      textDecoration = textDecoration,
      backgroundColor = backgroundColor,
    )

  internal companion object {
    fun merge(
      existing: LinkStylePatch?,
      block: LinkStyleScope.() -> Unit,
    ): LinkStylePatch {
      val scope =
        LinkStyleScope().apply {
          if (existing != null) {
            fontFamily = existing.fontFamily
            color = existing.color
            textDecoration = existing.textDecoration
            backgroundColor = existing.backgroundColor
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}
