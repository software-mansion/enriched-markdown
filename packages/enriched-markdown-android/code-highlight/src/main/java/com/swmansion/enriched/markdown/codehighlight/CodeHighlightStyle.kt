package com.swmansion.enriched.markdown.codehighlight

import android.graphics.Color
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.StyleExtensionKey

/**
 * Per-token foreground colors for highlighted code blocks, as ARGB. A type without a color keeps
 * the code block's own text color. Immutable: [with] returns a copy.
 *
 * A style stored under [CodeHighlightStyleKey] is laid over the default palette rather than
 * replacing it, as on iOS: its colors win, and a type it leaves null takes the palette's color.
 * The palette is [githubDark] on a dark code block background and [githubLight] otherwise.
 */
class CodeHighlightStyle private constructor(
  private val colors: Array<Int?>,
) {
  /** A style with no colors of its own; laid over the default palette, it changes nothing. */
  constructor() : this(arrayOfNulls(TOKEN_TYPES.size))

  /** The color for [type], or null when this style leaves it unset. */
  operator fun get(type: SyntaxTokenType): Int? = colors[type.ordinal]

  /** A copy with [type] colored [color]; null unsets it. */
  fun with(
    type: SyntaxTokenType,
    color: Int?,
  ): CodeHighlightStyle = CodeHighlightStyle(colors.copyOf().also { it[type.ordinal] = color })

  /** This style's colors, with [fallback]'s for every type this one leaves unset. */
  fun over(fallback: CodeHighlightStyle): CodeHighlightStyle = CodeHighlightStyle(Array(colors.size) { colors[it] ?: fallback.colors[it] })

  override fun equals(other: Any?): Boolean = other is CodeHighlightStyle && colors.contentEquals(other.colors)

  override fun hashCode(): Int = colors.contentHashCode()

  override fun toString(): String =
    TOKEN_TYPES
      .filter { this[it] != null }
      .joinToString(prefix = "CodeHighlightStyle(", postfix = ")") { "$it=#%08X".format(this[it]) }

  companion object {
    private val TOKEN_TYPES = SyntaxTokenType.entries

    // GitHub's palettes, the same values iOS uses. Operators, punctuation, variables and embedded
    // code have no color of their own in either and keep the block's.
    private val GITHUB_LIGHT =
      palette(
        SyntaxTokenType.KEYWORD to 0xCF222E,
        SyntaxTokenType.STRING to 0x0A3069,
        SyntaxTokenType.NUMBER to 0x0550AE,
        SyntaxTokenType.CONSTANT to 0x0550AE,
        SyntaxTokenType.COMMENT to 0x6E7781,
        SyntaxTokenType.FUNCTION to 0x8250DF,
        SyntaxTokenType.TYPE to 0x953800,
        SyntaxTokenType.PROPERTY to 0x0550AE,
        SyntaxTokenType.TAG to 0x116329,
        SyntaxTokenType.ATTRIBUTE to 0x0550AE,
      )

    private val GITHUB_DARK =
      palette(
        SyntaxTokenType.KEYWORD to 0xFF7B72,
        SyntaxTokenType.STRING to 0xA5D6FF,
        SyntaxTokenType.NUMBER to 0x79C0FF,
        SyntaxTokenType.CONSTANT to 0x79C0FF,
        SyntaxTokenType.COMMENT to 0x8B949E,
        SyntaxTokenType.FUNCTION to 0xD2A8FF,
        SyntaxTokenType.TYPE to 0xFFA657,
        SyntaxTokenType.PROPERTY to 0x79C0FF,
        SyntaxTokenType.TAG to 0x7EE787,
        SyntaxTokenType.ATTRIBUTE to 0x79C0FF,
      )

    /** GitHub's light palette, for code on a light background. */
    fun githubLight(): CodeHighlightStyle = GITHUB_LIGHT

    /** GitHub's dark palette, for code on a dark background. */
    fun githubDark(): CodeHighlightStyle = GITHUB_DARK

    /**
     * [githubDark] when white text contrasts with [backgroundColor] more than black text does,
     * [githubLight] otherwise. Alpha is ignored except that a fully transparent background, which
     * says nothing about what shows through it, gets the light palette.
     */
    fun defaultFor(backgroundColor: Int): CodeHighlightStyle =
      if (Color.alpha(backgroundColor) != 0 && Color.luminance(backgroundColor) < DARK_LUMINANCE) GITHUB_DARK else GITHUB_LIGHT

    // Relative luminance at which black and white text have equal WCAG contrast:
    // (L + 0.05) / 0.05 == 1.05 / (L + 0.05).
    private const val DARK_LUMINANCE = 0.179f

    private fun palette(vararg colors: Pair<SyntaxTokenType, Int>): CodeHighlightStyle =
      colors.fold(CodeHighlightStyle()) { style, (type, rgb) -> style.with(type, OPAQUE or rgb) }

    private const val OPAQUE = 0xFF000000.toInt()
  }
}

/** The handle an explicit [CodeHighlightStyle] is stored under in [StyleConfig.extensions]. */
val CodeHighlightStyleKey: StyleExtensionKey<CodeHighlightStyle> =
  StyleExtensionKey("com.swmansion.enriched.markdown.codehighlight:codeHighlight")

/**
 * The colors code blocks are highlighted with: the style stored under [CodeHighlightStyleKey]
 * laid over the default palette for [StyleConfig.codeBlockStyle]'s background.
 */
fun StyleConfig.codeHighlightStyle(): CodeHighlightStyle {
  val palette = CodeHighlightStyle.defaultFor(codeBlockStyle.backgroundColor)
  return get(CodeHighlightStyleKey)?.over(palette) ?: palette
}
