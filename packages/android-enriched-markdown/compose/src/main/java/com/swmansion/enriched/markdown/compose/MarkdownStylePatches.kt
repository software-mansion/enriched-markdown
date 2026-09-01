package com.swmansion.enriched.markdown.compose

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import com.swmansion.enriched.markdown.compose.style.FontFamilyResolver
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.compose.style.StyleUnits
import com.swmansion.enriched.markdown.compose.style.toEmphasisStyleString
import com.swmansion.enriched.markdown.compose.style.toStyleWeight
import com.swmansion.enriched.markdown.styles.BlockquoteStyle
import com.swmansion.enriched.markdown.styles.CodeBlockStyle
import com.swmansion.enriched.markdown.styles.CodeStyle
import com.swmansion.enriched.markdown.styles.EmphasisStyle
import com.swmansion.enriched.markdown.styles.HeadingStyle
import com.swmansion.enriched.markdown.styles.ImageStyle
import com.swmansion.enriched.markdown.styles.InlineImageStyle
import com.swmansion.enriched.markdown.styles.LinkStyle
import com.swmansion.enriched.markdown.styles.ListStyle
import com.swmansion.enriched.markdown.styles.ParagraphStyle
import com.swmansion.enriched.markdown.styles.StrikethroughStyle
import com.swmansion.enriched.markdown.styles.StrongStyle
import com.swmansion.enriched.markdown.styles.TextAlignment
import com.swmansion.enriched.markdown.styles.ThematicBreakStyle
import com.swmansion.enriched.markdown.styles.UnderlineStyle

@Immutable
internal data class TextStylePatch(
  val fontSize: TextUnit? = null,
  val fontFamily: FontFamily? = null,
  val fontWeight: FontWeight? = null,
  val color: Color? = null,
  val lineHeight: TextUnit? = null,
  val marginTop: Dp? = null,
  val marginBottom: Dp? = null,
  val textAlign: TextAlignment? = null,
) {
  fun apply(
    base: ParagraphStyle,
    resolveContext: StyleResolveContext,
    units: StyleUnits,
  ): ParagraphStyle =
    base.copy(
      fontSize = fontSize?.let(units::sp) ?: base.fontSize,
      fontFamily = fontFamily?.let { FontFamilyResolver.resolve(it, resolveContext) } ?: base.fontFamily,
      fontWeight = fontWeight?.toStyleWeight() ?: base.fontWeight,
      color = color?.let(units::color) ?: base.color,
      lineHeight = lineHeight?.let(units::sp) ?: base.lineHeight,
      marginTop = marginTop?.let(units::dp) ?: base.marginTop,
      marginBottom = marginBottom?.let(units::dp) ?: base.marginBottom,
      textAlign = textAlign ?: base.textAlign,
    )

  fun apply(
    base: HeadingStyle,
    resolveContext: StyleResolveContext,
    units: StyleUnits,
  ): HeadingStyle =
    base.copy(
      fontSize = fontSize?.let(units::sp) ?: base.fontSize,
      fontFamily = fontFamily?.let { FontFamilyResolver.resolve(it, resolveContext) } ?: base.fontFamily,
      fontWeight = fontWeight?.toStyleWeight() ?: base.fontWeight,
      color = color?.let(units::color) ?: base.color,
      lineHeight = lineHeight?.let(units::sp) ?: base.lineHeight,
      marginTop = marginTop?.let(units::dp) ?: base.marginTop,
      marginBottom = marginBottom?.let(units::dp) ?: base.marginBottom,
      textAlign = textAlign ?: base.textAlign,
    )
}

@MarkdownStyleDsl
class TextStyleScope {
  var fontSize: TextUnit? = null
  var fontFamily: FontFamily? = null
  var fontWeight: FontWeight? = null
  var color: Color? = null
  var lineHeight: TextUnit? = null
  var marginTop: Dp? = null
  var marginBottom: Dp? = null
  var textAlign: TextAlignment? = null

  internal fun toPatch(): TextStylePatch =
    TextStylePatch(
      fontSize = fontSize,
      fontFamily = fontFamily,
      fontWeight = fontWeight,
      color = color,
      lineHeight = lineHeight,
      marginTop = marginTop,
      marginBottom = marginBottom,
      textAlign = textAlign,
    )

  internal companion object {
    fun merge(
      existing: TextStylePatch?,
      block: TextStyleScope.() -> Unit,
    ): TextStylePatch {
      val scope =
        TextStyleScope().apply {
          if (existing != null) {
            fontSize = existing.fontSize
            fontFamily = existing.fontFamily
            fontWeight = existing.fontWeight
            color = existing.color
            lineHeight = existing.lineHeight
            marginTop = existing.marginTop
            marginBottom = existing.marginBottom
            textAlign = existing.textAlign
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}

typealias ParagraphStyleScope = TextStyleScope
typealias HeadingStyleScope = TextStyleScope

@Immutable
internal data class LinkStylePatch(
  val fontFamily: FontFamily? = null,
  val color: Color? = null,
  val underline: Boolean? = null,
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
      underline = underline ?: base.underline,
      backgroundColor = backgroundColor?.let(units::color) ?: base.backgroundColor,
    )
}

@MarkdownStyleDsl
class LinkStyleScope {
  var fontFamily: FontFamily? = null
  var color: Color? = null
  var underline: Boolean? = null
  var backgroundColor: Color? = null

  internal fun toPatch(): LinkStylePatch =
    LinkStylePatch(
      fontFamily = fontFamily,
      color = color,
      underline = underline,
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
            underline = existing.underline
            backgroundColor = existing.backgroundColor
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}

@Immutable
internal data class StrongStylePatch(
  val fontFamily: FontFamily? = null,
  val fontWeight: FontWeight? = null,
  val color: Color? = null,
) {
  fun apply(
    base: StrongStyle,
    resolveContext: StyleResolveContext,
    units: StyleUnits,
  ): StrongStyle =
    base.copy(
      fontFamily = fontFamily?.let { FontFamilyResolver.resolve(it, resolveContext) } ?: base.fontFamily,
      fontWeight = fontWeight?.toStyleWeight() ?: base.fontWeight,
      color = color?.let(units::color) ?: base.color,
    )
}

@MarkdownStyleDsl
class StrongStyleScope {
  var fontFamily: FontFamily? = null
  var fontWeight: FontWeight? = null
  var color: Color? = null

  internal fun toPatch(): StrongStylePatch =
    StrongStylePatch(
      fontFamily = fontFamily,
      fontWeight = fontWeight,
      color = color,
    )

  internal companion object {
    fun merge(
      existing: StrongStylePatch?,
      block: StrongStyleScope.() -> Unit,
    ): StrongStylePatch {
      val scope =
        StrongStyleScope().apply {
          if (existing != null) {
            fontFamily = existing.fontFamily
            fontWeight = existing.fontWeight
            color = existing.color
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}

@Immutable
internal data class EmphasisStylePatch(
  val fontFamily: FontFamily? = null,
  val fontStyle: FontStyle? = null,
  val color: Color? = null,
) {
  fun apply(
    base: EmphasisStyle,
    resolveContext: StyleResolveContext,
    units: StyleUnits,
  ): EmphasisStyle =
    base.copy(
      fontFamily = fontFamily?.let { FontFamilyResolver.resolve(it, resolveContext) } ?: base.fontFamily,
      fontStyle = fontStyle?.toEmphasisStyleString() ?: base.fontStyle,
      color = color?.let(units::color) ?: base.color,
    )
}

@MarkdownStyleDsl
class EmphasisStyleScope {
  var fontFamily: FontFamily? = null
  var fontStyle: FontStyle? = null
  var color: Color? = null

  internal fun toPatch(): EmphasisStylePatch =
    EmphasisStylePatch(
      fontFamily = fontFamily,
      fontStyle = fontStyle,
      color = color,
    )

  internal companion object {
    fun merge(
      existing: EmphasisStylePatch?,
      block: EmphasisStyleScope.() -> Unit,
    ): EmphasisStylePatch {
      val scope =
        EmphasisStyleScope().apply {
          if (existing != null) {
            fontFamily = existing.fontFamily
            fontStyle = existing.fontStyle
            color = existing.color
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}

@Immutable
internal data class StrikethroughStylePatch(
  val color: Color? = null,
) {
  fun apply(
    base: StrikethroughStyle,
    units: StyleUnits,
  ): StrikethroughStyle = base.copy(color = color?.let(units::color) ?: base.color)
}

@MarkdownStyleDsl
class StrikethroughStyleScope {
  var color: Color? = null

  internal fun toPatch(): StrikethroughStylePatch = StrikethroughStylePatch(color = color)

  internal companion object {
    fun merge(
      existing: StrikethroughStylePatch?,
      block: StrikethroughStyleScope.() -> Unit,
    ): StrikethroughStylePatch {
      val scope =
        StrikethroughStyleScope().apply {
          if (existing != null) {
            color = existing.color
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}

@Immutable
internal data class UnderlineStylePatch(
  val color: Color? = null,
) {
  fun apply(
    base: UnderlineStyle,
    units: StyleUnits,
  ): UnderlineStyle = base.copy(color = color?.let(units::color) ?: base.color)
}

@MarkdownStyleDsl
class UnderlineStyleScope {
  var color: Color? = null

  internal fun toPatch(): UnderlineStylePatch = UnderlineStylePatch(color = color)

  internal companion object {
    fun merge(
      existing: UnderlineStylePatch?,
      block: UnderlineStyleScope.() -> Unit,
    ): UnderlineStylePatch {
      val scope =
        UnderlineStyleScope().apply {
          if (existing != null) {
            color = existing.color
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}

@Immutable
internal data class CodeStylePatch(
  val fontFamily: FontFamily? = null,
  val fontSize: TextUnit? = null,
  val color: Color? = null,
  val backgroundColor: Color? = null,
  val borderColor: Color? = null,
) {
  fun apply(
    base: CodeStyle,
    resolveContext: StyleResolveContext,
    units: StyleUnits,
  ): CodeStyle =
    base.copy(
      fontFamily = fontFamily?.let { FontFamilyResolver.resolve(it, resolveContext) } ?: base.fontFamily,
      fontSize = fontSize?.let(units::sp) ?: base.fontSize,
      color = color?.let(units::color) ?: base.color,
      backgroundColor = backgroundColor?.let(units::color) ?: base.backgroundColor,
      borderColor = borderColor?.let(units::color) ?: base.borderColor,
    )
}

@MarkdownStyleDsl
class CodeStyleScope {
  var fontFamily: FontFamily? = null
  var fontSize: TextUnit? = null
  var color: Color? = null
  var backgroundColor: Color? = null
  var borderColor: Color? = null

  internal fun toPatch(): CodeStylePatch =
    CodeStylePatch(
      fontFamily = fontFamily,
      fontSize = fontSize,
      color = color,
      backgroundColor = backgroundColor,
      borderColor = borderColor,
    )

  internal companion object {
    fun merge(
      existing: CodeStylePatch?,
      block: CodeStyleScope.() -> Unit,
    ): CodeStylePatch {
      val scope =
        CodeStyleScope().apply {
          if (existing != null) {
            fontFamily = existing.fontFamily
            fontSize = existing.fontSize
            color = existing.color
            backgroundColor = existing.backgroundColor
            borderColor = existing.borderColor
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}

@Immutable
internal data class CodeBlockStylePatch(
  val fontSize: TextUnit? = null,
  val fontFamily: FontFamily? = null,
  val fontWeight: FontWeight? = null,
  val color: Color? = null,
  val lineHeight: TextUnit? = null,
  val marginTop: Dp? = null,
  val marginBottom: Dp? = null,
  val backgroundColor: Color? = null,
  val borderColor: Color? = null,
  val cornerRadius: Dp? = null,
  val borderWidth: Dp? = null,
  val padding: Dp? = null,
) {
  fun apply(
    base: CodeBlockStyle,
    resolveContext: StyleResolveContext,
    units: StyleUnits,
  ): CodeBlockStyle =
    base.copy(
      fontSize = fontSize?.let(units::sp) ?: base.fontSize,
      fontFamily = fontFamily?.let { FontFamilyResolver.resolve(it, resolveContext) } ?: base.fontFamily,
      fontWeight = fontWeight?.toStyleWeight() ?: base.fontWeight,
      color = color?.let(units::color) ?: base.color,
      lineHeight = lineHeight?.let(units::sp) ?: base.lineHeight,
      marginTop = marginTop?.let(units::dp) ?: base.marginTop,
      marginBottom = marginBottom?.let(units::dp) ?: base.marginBottom,
      backgroundColor = backgroundColor?.let(units::color) ?: base.backgroundColor,
      borderColor = borderColor?.let(units::color) ?: base.borderColor,
      borderRadius = cornerRadius?.let(units::dp) ?: base.borderRadius,
      borderWidth = borderWidth?.let(units::dp) ?: base.borderWidth,
      padding = padding?.let(units::dp) ?: base.padding,
    )
}

@MarkdownStyleDsl
class CodeBlockStyleScope {
  var fontSize: TextUnit? = null
  var fontFamily: FontFamily? = null
  var fontWeight: FontWeight? = null
  var color: Color? = null
  var lineHeight: TextUnit? = null
  var marginTop: Dp? = null
  var marginBottom: Dp? = null
  var backgroundColor: Color? = null
  var borderColor: Color? = null
  var cornerRadius: Dp? = null
  var borderWidth: Dp? = null
  var padding: Dp? = null

  internal fun toPatch(): CodeBlockStylePatch =
    CodeBlockStylePatch(
      fontSize = fontSize,
      fontFamily = fontFamily,
      fontWeight = fontWeight,
      color = color,
      lineHeight = lineHeight,
      marginTop = marginTop,
      marginBottom = marginBottom,
      backgroundColor = backgroundColor,
      borderColor = borderColor,
      cornerRadius = cornerRadius,
      borderWidth = borderWidth,
      padding = padding,
    )

  internal companion object {
    fun merge(
      existing: CodeBlockStylePatch?,
      block: CodeBlockStyleScope.() -> Unit,
    ): CodeBlockStylePatch {
      val scope =
        CodeBlockStyleScope().apply {
          if (existing != null) {
            fontSize = existing.fontSize
            fontFamily = existing.fontFamily
            fontWeight = existing.fontWeight
            color = existing.color
            lineHeight = existing.lineHeight
            marginTop = existing.marginTop
            marginBottom = existing.marginBottom
            backgroundColor = existing.backgroundColor
            borderColor = existing.borderColor
            cornerRadius = existing.cornerRadius
            borderWidth = existing.borderWidth
            padding = existing.padding
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}

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
    )
}

@MarkdownStyleDsl
class BlockquoteStyleScope {
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
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}

@Immutable
internal data class ListStylePatch(
  val fontSize: TextUnit? = null,
  val fontFamily: FontFamily? = null,
  val fontWeight: FontWeight? = null,
  val color: Color? = null,
  val lineHeight: TextUnit? = null,
  val marginTop: Dp? = null,
  val marginBottom: Dp? = null,
  val bulletColor: Color? = null,
  val bulletSize: Dp? = null,
  val markerMinWidth: Dp? = null,
  val markerColor: Color? = null,
  val markerFontWeight: FontWeight? = null,
  val gapWidth: Dp? = null,
  val marginLeft: Dp? = null,
) {
  fun apply(
    base: ListStyle,
    resolveContext: StyleResolveContext,
    units: StyleUnits,
  ): ListStyle =
    base.copy(
      fontSize = fontSize?.let(units::sp) ?: base.fontSize,
      fontFamily = fontFamily?.let { FontFamilyResolver.resolve(it, resolveContext) } ?: base.fontFamily,
      fontWeight = fontWeight?.toStyleWeight() ?: base.fontWeight,
      color = color?.let(units::color) ?: base.color,
      lineHeight = lineHeight?.let(units::sp) ?: base.lineHeight,
      marginTop = marginTop?.let(units::dp) ?: base.marginTop,
      marginBottom = marginBottom?.let(units::dp) ?: base.marginBottom,
      bulletColor = bulletColor?.let(units::color) ?: base.bulletColor,
      bulletSize = bulletSize?.let(units::dp) ?: base.bulletSize,
      markerMinWidth = markerMinWidth?.let(units::dp) ?: base.markerMinWidth,
      markerColor = markerColor?.let(units::color) ?: base.markerColor,
      markerFontWeight = markerFontWeight?.toStyleWeight() ?: base.markerFontWeight,
      gapWidth = gapWidth?.let(units::dp) ?: base.gapWidth,
      marginLeft = marginLeft?.let(units::dp) ?: base.marginLeft,
    )
}

@MarkdownStyleDsl
class ListStyleScope {
  var fontSize: TextUnit? = null
  var fontFamily: FontFamily? = null
  var fontWeight: FontWeight? = null
  var color: Color? = null
  var lineHeight: TextUnit? = null
  var marginTop: Dp? = null
  var marginBottom: Dp? = null
  var bulletColor: Color? = null
  var bulletSize: Dp? = null
  var markerMinWidth: Dp? = null
  var markerColor: Color? = null
  var markerFontWeight: FontWeight? = null
  var gapWidth: Dp? = null
  var marginLeft: Dp? = null

  internal fun toPatch(): ListStylePatch =
    ListStylePatch(
      fontSize = fontSize,
      fontFamily = fontFamily,
      fontWeight = fontWeight,
      color = color,
      lineHeight = lineHeight,
      marginTop = marginTop,
      marginBottom = marginBottom,
      bulletColor = bulletColor,
      bulletSize = bulletSize,
      markerMinWidth = markerMinWidth,
      markerColor = markerColor,
      markerFontWeight = markerFontWeight,
      gapWidth = gapWidth,
      marginLeft = marginLeft,
    )

  internal companion object {
    fun merge(
      existing: ListStylePatch?,
      block: ListStyleScope.() -> Unit,
    ): ListStylePatch {
      val scope =
        ListStyleScope().apply {
          if (existing != null) {
            fontSize = existing.fontSize
            fontFamily = existing.fontFamily
            fontWeight = existing.fontWeight
            color = existing.color
            lineHeight = existing.lineHeight
            marginTop = existing.marginTop
            marginBottom = existing.marginBottom
            bulletColor = existing.bulletColor
            bulletSize = existing.bulletSize
            markerMinWidth = existing.markerMinWidth
            markerColor = existing.markerColor
            markerFontWeight = existing.markerFontWeight
            gapWidth = existing.gapWidth
            marginLeft = existing.marginLeft
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}

@Immutable
internal data class ImageStylePatch(
  val height: Dp? = null,
  val borderRadius: Dp? = null,
  val marginTop: Dp? = null,
  val marginBottom: Dp? = null,
) {
  fun apply(
    base: ImageStyle,
    units: StyleUnits,
  ): ImageStyle =
    base.copy(
      height = height?.let(units::dp) ?: base.height,
      borderRadius = borderRadius?.let(units::dp) ?: base.borderRadius,
      marginTop = marginTop?.let(units::dp) ?: base.marginTop,
      marginBottom = marginBottom?.let(units::dp) ?: base.marginBottom,
    )
}

@MarkdownStyleDsl
class ImageStyleScope {
  var height: Dp? = null
  var borderRadius: Dp? = null
  var marginTop: Dp? = null
  var marginBottom: Dp? = null

  internal fun toPatch(): ImageStylePatch =
    ImageStylePatch(
      height = height,
      borderRadius = borderRadius,
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
            borderRadius = existing.borderRadius
            marginTop = existing.marginTop
            marginBottom = existing.marginBottom
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}

@Immutable
internal data class InlineImageStylePatch(
  val size: Dp? = null,
) {
  fun apply(
    base: InlineImageStyle,
    units: StyleUnits,
  ): InlineImageStyle =
    base.copy(
      size = size?.let(units::dp) ?: base.size,
    )
}

@MarkdownStyleDsl
class InlineImageStyleScope {
  var size: Dp? = null

  internal fun toPatch(): InlineImageStylePatch = InlineImageStylePatch(size = size)

  internal companion object {
    fun merge(
      existing: InlineImageStylePatch?,
      block: InlineImageStyleScope.() -> Unit,
    ): InlineImageStylePatch {
      val scope =
        InlineImageStyleScope().apply {
          if (existing != null) {
            size = existing.size
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}

@Immutable
internal data class ThematicBreakStylePatch(
  val color: Color? = null,
  val height: Dp? = null,
  val marginTop: Dp? = null,
  val marginBottom: Dp? = null,
) {
  fun apply(
    base: ThematicBreakStyle,
    units: StyleUnits,
  ): ThematicBreakStyle =
    base.copy(
      color = color?.let(units::color) ?: base.color,
      height = height?.let(units::dp) ?: base.height,
      marginTop = marginTop?.let(units::dp) ?: base.marginTop,
      marginBottom = marginBottom?.let(units::dp) ?: base.marginBottom,
    )
}

@MarkdownStyleDsl
class ThematicBreakStyleScope {
  var color: Color? = null
  var height: Dp? = null
  var marginTop: Dp? = null
  var marginBottom: Dp? = null

  internal fun toPatch(): ThematicBreakStylePatch =
    ThematicBreakStylePatch(
      color = color,
      height = height,
      marginTop = marginTop,
      marginBottom = marginBottom,
    )

  internal companion object {
    fun merge(
      existing: ThematicBreakStylePatch?,
      block: ThematicBreakStyleScope.() -> Unit,
    ): ThematicBreakStylePatch {
      val scope =
        ThematicBreakStyleScope().apply {
          if (existing != null) {
            color = existing.color
            height = existing.height
            marginTop = existing.marginTop
            marginBottom = existing.marginBottom
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}
