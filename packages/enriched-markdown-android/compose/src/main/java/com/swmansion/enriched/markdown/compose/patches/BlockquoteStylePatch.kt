package com.swmansion.enriched.markdown.compose.patches

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.FontFamilyResolver
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.compose.style.StyleUnits
import com.swmansion.enriched.markdown.compose.style.toStyleWeight
import com.swmansion.enriched.markdown.styles.AdmonitionColors
import com.swmansion.enriched.markdown.styles.BlockquoteStyle

@Immutable
internal data class BlockquoteStylePatch(
  val fontSize: TextUnit? = null,
  val fontFamily: FontFamily? = null,
  val fontWeight: FontWeight? = null,
  val color: Color? = null,
  val lineHeight: TextUnit? = null,
  val marginTop: Dp? = null,
  val marginBottom: Dp? = null,
  val borderColor: Color? = null,
  val borderWidth: Dp? = null,
  val gapWidth: Dp? = null,
  val backgroundColor: Color? = null,
  val cornerRadius: Dp? = null,
  val padding: Dp? = null,
  val admonitions: Map<String, AdmonitionColorsPatch> = emptyMap(),
) {
  fun apply(
    base: BlockquoteStyle,
    resolveContext: StyleResolveContext,
    units: StyleUnits,
  ): BlockquoteStyle =
    base.copy(
      fontSize = fontSize?.let(units::sp) ?: base.fontSize,
      fontFamily = fontFamily?.let { FontFamilyResolver.resolve(it, resolveContext) } ?: base.fontFamily,
      fontWeight = fontWeight?.toStyleWeight() ?: base.fontWeight,
      color = color?.let(units::color) ?: base.color,
      lineHeight = lineHeight?.let(units::sp) ?: base.lineHeight,
      marginTop = marginTop?.let(units::dp) ?: base.marginTop,
      marginBottom = marginBottom?.let(units::dp) ?: base.marginBottom,
      borderColor = borderColor?.let(units::color) ?: base.borderColor,
      borderWidth = borderWidth?.let(units::dp) ?: base.borderWidth,
      gapWidth = gapWidth?.let(units::dp) ?: base.gapWidth,
      backgroundColor = backgroundColor?.let(units::color) ?: base.backgroundColor,
      borderRadius = cornerRadius?.let(units::dp) ?: base.borderRadius,
      padding = padding?.let(units::dp) ?: base.padding,
      admonitions = applyAdmonitions(base, units),
    )

  private fun applyAdmonitions(
    base: BlockquoteStyle,
    units: StyleUnits,
  ): Map<String, AdmonitionColors> {
    if (admonitions.isEmpty()) return base.admonitions

    val merged = base.admonitions.toMutableMap()
    for ((type, patch) in admonitions) {
      val existing = merged[type]
      merged[type] =
        AdmonitionColors(
          color = patch.color?.let(units::color) ?: existing?.color ?: base.borderColor,
          backgroundColor = patch.backgroundColor?.let(units::color) ?: existing?.backgroundColor,
        )
    }
    return merged
  }
}

@Immutable
internal data class AdmonitionColorsPatch(
  val color: Color? = null,
  val backgroundColor: Color? = null,
)

/** Colors of a single admonition type. */
@MarkdownStyleDsl
class AdmonitionColorsScope internal constructor() {
  /** Tints the accent bar, the header title and the header icon. */
  var color: Color? = null

  /** Fill of the box. Left unset, the admonition is drawn unfilled. */
  var backgroundColor: Color? = null

  internal fun toPatch(): AdmonitionColorsPatch = AdmonitionColorsPatch(color, backgroundColor)
}

/**
 * The five GitHub alert types. Each block overrides only the type it names; types left untouched
 * keep the GitHub palette from the defaults.
 */
@MarkdownStyleDsl
class AdmonitionsStyleScope internal constructor() {
  private val patches = mutableMapOf<String, AdmonitionColorsPatch>()

  fun note(block: AdmonitionColorsScope.() -> Unit) = type("note", block)

  fun tip(block: AdmonitionColorsScope.() -> Unit) = type("tip", block)

  fun important(block: AdmonitionColorsScope.() -> Unit) = type("important", block)

  fun warning(block: AdmonitionColorsScope.() -> Unit) = type("warning", block)

  fun caution(block: AdmonitionColorsScope.() -> Unit) = type("caution", block)

  private fun type(
    name: String,
    block: AdmonitionColorsScope.() -> Unit,
  ) {
    val existing = patches[name]
    val scope =
      AdmonitionColorsScope().apply {
        color = existing?.color
        backgroundColor = existing?.backgroundColor
      }
    scope.block()
    patches[name] = scope.toPatch()
  }

  internal fun toPatch(): Map<String, AdmonitionColorsPatch> = patches.toMap()

  internal companion object {
    fun merge(
      existing: Map<String, AdmonitionColorsPatch>,
      block: AdmonitionsStyleScope.() -> Unit,
    ): Map<String, AdmonitionColorsPatch> {
      val scope = AdmonitionsStyleScope()
      existing.forEach { (name, patch) ->
        scope.type(name) {
          color = patch.color
          backgroundColor = patch.backgroundColor
        }
      }
      scope.block()
      return scope.toPatch()
    }
  }
}

@MarkdownStyleDsl
class BlockquoteStyleScope internal constructor() {
  var fontSize: TextUnit? = null
  var fontFamily: FontFamily? = null
  var fontWeight: FontWeight? = null
  var color: Color? = null
  var lineHeight: TextUnit? = null
  var marginTop: Dp? = null
  var marginBottom: Dp? = null
  var borderColor: Color? = null
  var borderWidth: Dp? = null
  var gapWidth: Dp? = null
  var backgroundColor: Color? = null
  var cornerRadius: Dp? = null

  var padding: Dp? = null

  private var admonitions: Map<String, AdmonitionColorsPatch> = emptyMap()

  /** Per-type colors for GitHub admonitions (`> [!NOTE]`, `> [!WARNING]`, …). */
  fun admonitions(block: AdmonitionsStyleScope.() -> Unit) {
    admonitions = AdmonitionsStyleScope.merge(admonitions, block)
  }

  internal fun toPatch(): BlockquoteStylePatch =
    BlockquoteStylePatch(
      fontSize = fontSize,
      fontFamily = fontFamily,
      fontWeight = fontWeight,
      color = color,
      lineHeight = lineHeight,
      marginTop = marginTop,
      marginBottom = marginBottom,
      borderColor = borderColor,
      borderWidth = borderWidth,
      gapWidth = gapWidth,
      backgroundColor = backgroundColor,
      cornerRadius = cornerRadius,
      padding = padding,
      admonitions = admonitions,
    )

  internal companion object {
    fun merge(
      existing: BlockquoteStylePatch?,
      block: BlockquoteStyleScope.() -> Unit,
    ): BlockquoteStylePatch {
      val scope =
        BlockquoteStyleScope().apply {
          if (existing != null) {
            fontSize = existing.fontSize
            fontFamily = existing.fontFamily
            fontWeight = existing.fontWeight
            color = existing.color
            lineHeight = existing.lineHeight
            marginTop = existing.marginTop
            marginBottom = existing.marginBottom
            borderColor = existing.borderColor
            borderWidth = existing.borderWidth
            gapWidth = existing.gapWidth
            backgroundColor = existing.backgroundColor
            cornerRadius = existing.cornerRadius
            padding = existing.padding
            admonitions = existing.admonitions
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}
