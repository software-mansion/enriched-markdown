@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.codehighlight.compose

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import com.swmansion.enriched.markdown.codehighlight.CodeHighlightStyle
import com.swmansion.enriched.markdown.codehighlight.CodeHighlightStyleKey
import com.swmansion.enriched.markdown.codehighlight.SyntaxTokenType
import com.swmansion.enriched.markdown.compose.MarkdownStyleBuilder
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.PluginStylePatch
import com.swmansion.enriched.markdown.compose.style.PluginStyleUnits
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import kotlin.properties.ReadWriteProperty
import kotlin.reflect.KProperty

/**
 * Pending token colors. A data class, not a lambda: style layers are compared by equality to
 * decide whether Compose has to recompose.
 */
@Immutable
internal data class CodeHighlightStylePatch(
  val colors: Map<SyntaxTokenType, Color> = emptyMap(),
) : PluginStylePatch<CodeHighlightStyle> {
  override fun apply(
    base: CodeHighlightStyle?,
    units: PluginStyleUnits,
  ): CodeHighlightStyle =
    // No base starts from an empty style, not a palette: the palette depends on the code block's
    // background, which is only known once the whole style has resolved.
    colors.entries.fold(base ?: CodeHighlightStyle()) { style, (type, color) -> style.with(type, units.argb(color)) }
}

/**
 * Token colors for highlighted code blocks. A token left null takes the default palette's color,
 * GitHub's light or dark one by the code block's background; see [CodeHighlightStyle].
 */
@MarkdownStyleDsl
class CodeHighlightStyleScope internal constructor(
  existing: CodeHighlightStylePatch?,
) {
  private val colors = existing?.colors.orEmpty().toMutableMap()

  var keyword: Color? by token(SyntaxTokenType.KEYWORD)
  var operator: Color? by token(SyntaxTokenType.OPERATOR)
  var punctuation: Color? by token(SyntaxTokenType.PUNCTUATION)
  var string: Color? by token(SyntaxTokenType.STRING)
  var number: Color? by token(SyntaxTokenType.NUMBER)
  var constant: Color? by token(SyntaxTokenType.CONSTANT)
  var comment: Color? by token(SyntaxTokenType.COMMENT)
  var function: Color? by token(SyntaxTokenType.FUNCTION)
  var type: Color? by token(SyntaxTokenType.TYPE)
  var variable: Color? by token(SyntaxTokenType.VARIABLE)
  var property: Color? by token(SyntaxTokenType.PROPERTY)
  var tag: Color? by token(SyntaxTokenType.TAG)
  var attribute: Color? by token(SyntaxTokenType.ATTRIBUTE)
  var embedded: Color? by token(SyntaxTokenType.EMBEDDED)

  /** The color for [type], for code that picks the token at runtime. */
  operator fun set(
    type: SyntaxTokenType,
    color: Color?,
  ) {
    if (color == null) colors.remove(type) else colors[type] = color
  }

  operator fun get(type: SyntaxTokenType): Color? = colors[type]

  internal fun toPatch(): CodeHighlightStylePatch = CodeHighlightStylePatch(colors.toMap())

  private fun token(type: SyntaxTokenType) =
    object : ReadWriteProperty<CodeHighlightStyleScope, Color?> {
      override fun getValue(
        thisRef: CodeHighlightStyleScope,
        property: KProperty<*>,
      ): Color? = colors[type]

      override fun setValue(
        thisRef: CodeHighlightStyleScope,
        property: KProperty<*>,
        value: Color?,
      ) = set(type, value)
    }
}

/**
 * Colors syntax tokens from core's Compose style DSL:
 *
 * ```
 * markdownStyle {
 *   codeHighlight {
 *     keyword = Color(0xFFD73A49)
 *     comment = Color(0xFF6A737D)
 *   }
 * }
 * ```
 *
 * Repeating the block merges into the earlier one rather than replacing it.
 *
 * This is the only part of the plugin that touches `:compose`, which is why the plugin depends on
 * it at compile time only: an app rendering through the View API never loads these.
 */
fun MarkdownStyleBuilder.codeHighlight(block: CodeHighlightStyleScope.() -> Unit) =
  updatePluginPatch(CodeHighlightStyleKey) { existing: CodeHighlightStylePatch? ->
    CodeHighlightStyleScope(existing).apply(block).toPatch()
  }
