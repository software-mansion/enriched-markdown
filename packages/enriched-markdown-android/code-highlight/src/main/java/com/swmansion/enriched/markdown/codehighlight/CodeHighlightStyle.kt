package com.swmansion.enriched.markdown.codehighlight

import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.StyleExtensionKey

/**
 * Per-token foreground colors for highlighted code blocks, as ARGB. A type without a color keeps
 * the code block's own text color.
 *
 * A style stored under [CodeHighlightStyleKey] is laid over [Default] rather than replacing it,
 * as on iOS: its colors win, and a type it leaves null takes the default's color.
 */
data class CodeHighlightStyle(
  val keyword: Int? = null,
  val operator: Int? = null,
  val punctuation: Int? = null,
  val string: Int? = null,
  val number: Int? = null,
  val constant: Int? = null,
  val comment: Int? = null,
  val function: Int? = null,
  val type: Int? = null,
  val variable: Int? = null,
  val property: Int? = null,
  val tag: Int? = null,
  val attribute: Int? = null,
  val embedded: Int? = null,
) {
  /** The color for [type], or null when this style leaves it unset. */
  operator fun get(type: SyntaxTokenType): Int? =
    when (type) {
      SyntaxTokenType.KEYWORD -> keyword
      SyntaxTokenType.OPERATOR -> operator
      SyntaxTokenType.PUNCTUATION -> punctuation
      SyntaxTokenType.STRING -> string
      SyntaxTokenType.NUMBER -> number
      SyntaxTokenType.CONSTANT -> constant
      SyntaxTokenType.COMMENT -> comment
      SyntaxTokenType.FUNCTION -> function
      SyntaxTokenType.TYPE -> this.type
      SyntaxTokenType.VARIABLE -> variable
      SyntaxTokenType.PROPERTY -> property
      SyntaxTokenType.TAG -> tag
      SyntaxTokenType.ATTRIBUTE -> attribute
      SyntaxTokenType.EMBEDDED -> embedded
    }

  /** This style's colors, with [fallback]'s for every type this one leaves unset. */
  fun over(fallback: CodeHighlightStyle): CodeHighlightStyle = of { this[it] ?: fallback[it] }

  companion object {
    /**
     * GitHub's dark palette, made for the default dark code block. Operators, punctuation,
     * variables and embedded code have no color of their own and keep the block's. On a light code
     * block background, set the colors yourself.
     */
    val Default =
      CodeHighlightStyle(
        keyword = opaque(0xFF7B72),
        string = opaque(0xA5D6FF),
        number = opaque(0x79C0FF),
        constant = opaque(0x79C0FF),
        comment = opaque(0x8B949E),
        function = opaque(0xD2A8FF),
        type = opaque(0xFFA657),
        property = opaque(0x79C0FF),
        tag = opaque(0x7EE787),
        attribute = opaque(0x79C0FF),
      )

    /** A style with [color]'s result for every token type. */
    internal fun of(color: (SyntaxTokenType) -> Int?): CodeHighlightStyle =
      CodeHighlightStyle(
        keyword = color(SyntaxTokenType.KEYWORD),
        operator = color(SyntaxTokenType.OPERATOR),
        punctuation = color(SyntaxTokenType.PUNCTUATION),
        string = color(SyntaxTokenType.STRING),
        number = color(SyntaxTokenType.NUMBER),
        constant = color(SyntaxTokenType.CONSTANT),
        comment = color(SyntaxTokenType.COMMENT),
        function = color(SyntaxTokenType.FUNCTION),
        type = color(SyntaxTokenType.TYPE),
        variable = color(SyntaxTokenType.VARIABLE),
        property = color(SyntaxTokenType.PROPERTY),
        tag = color(SyntaxTokenType.TAG),
        attribute = color(SyntaxTokenType.ATTRIBUTE),
        embedded = color(SyntaxTokenType.EMBEDDED),
      )

    private fun opaque(rgb: Int): Int = 0xFF000000.toInt() or rgb
  }
}

/** The handle an explicit [CodeHighlightStyle] is stored under in [StyleConfig.extensions]. */
val CodeHighlightStyleKey: StyleExtensionKey<CodeHighlightStyle> =
  StyleExtensionKey("com.swmansion.enriched.markdown.codehighlight:codeHighlight")

/**
 * The colors code blocks are highlighted with: the style stored under [CodeHighlightStyleKey]
 * laid over [CodeHighlightStyle.Default].
 */
fun StyleConfig.codeHighlightStyle(): CodeHighlightStyle =
  get(CodeHighlightStyleKey)?.over(CodeHighlightStyle.Default) ?: CodeHighlightStyle.Default
