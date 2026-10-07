@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.syntaxhighlighting.test

import android.content.Context
import android.text.Spannable
import android.text.Spanned
import android.text.TextPaint
import android.text.style.CharacterStyle
import androidx.test.core.app.ApplicationProvider
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.MarkdownPlugin
import com.swmansion.enriched.markdown.plugin.PluginRegistry
import com.swmansion.enriched.markdown.plugin.PluginSnapshot
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.syntaxhighlighting.SyntaxHighlightDecorator
import com.swmansion.enriched.markdown.syntaxhighlighting.SyntaxTokenCache
import com.swmansion.enriched.markdown.syntaxhighlighting.SyntaxTokenSource
import com.swmansion.enriched.markdown.syntaxhighlighting.SyntaxTokenType

/**
 * The slice of core's own test support this module needs. Test sources are not published, so a
 * plugin module cannot share `:ui`'s copy.
 */
object SyntaxHighlightingTestSupport {
  // Resolved per call, not cached: a @Config qualifier is applied to the current test's context,
  // and a singleton would pin the first test's one.
  val context: Context
    get() = ApplicationProvider.getApplicationContext()

  val defaultStyle: StyleConfig get() = StyleConfig.default(context)

  fun render(
    document: MarkdownASTNode,
    style: StyleConfig = defaultStyle,
    plugins: PluginSnapshot = PluginSnapshot.EMPTY,
  ): Spannable {
    val renderer = Renderer()
    renderer.configure(style, context, plugins = plugins)
    return renderer.renderDocument(document, null, null)
  }

  /** The plugin's decorator over [source] instead of the native grammars, which the host JVM cannot load. */
  internal fun pluginWith(source: SyntaxTokenSource): PluginSnapshot =
    PluginSnapshot.of(
      object : MarkdownPlugin {
        override val id = "test-syntax-highlighting"

        override fun install(registry: PluginRegistry) =
          registry.registerCodeBlockDecorator(SyntaxHighlightDecorator(SyntaxTokenCache(source)))
      },
    )

  /** What [TextPaint] ends up with after every character style at [index], in the order layout applies them. */
  fun drawColorAt(
    text: Spanned,
    index: Int,
  ): Int {
    val paint = TextPaint()
    for (span in text.getSpans(index, index + 1, CharacterStyle::class.java)) {
      span.updateDrawState(paint)
    }
    return paint.color
  }

  fun document(vararg children: MarkdownASTNode): MarkdownASTNode = MarkdownASTNode(NodeType.Document, children = children.toList())

  fun paragraph(vararg children: MarkdownASTNode): MarkdownASTNode = MarkdownASTNode(NodeType.Paragraph, children = children.toList())

  fun text(content: String): MarkdownASTNode = MarkdownASTNode(NodeType.Text, content = content)

  fun codeBlock(
    content: String,
    language: String? = null,
  ): MarkdownASTNode =
    MarkdownASTNode(
      type = NodeType.CodeBlock,
      attributes = language?.let { mapOf("language" to it) }.orEmpty(),
      children = listOf(text(content)),
    )

  fun blockquote(vararg children: MarkdownASTNode): MarkdownASTNode = MarkdownASTNode(NodeType.Blockquote, children = children.toList())

  fun unorderedList(vararg items: MarkdownASTNode): MarkdownASTNode = MarkdownASTNode(NodeType.UnorderedList, children = items.toList())

  fun listItem(vararg children: MarkdownASTNode): MarkdownASTNode = MarkdownASTNode(NodeType.ListItem, children = children.toList())
}

/**
 * Tokens for one fixed snippet in [LANGUAGE], found by text; any other code or language gets none,
 * as a language without a compiled grammar does. Counts its calls.
 */
internal class FakeTokenSource(
  private val tokens: List<Pair<String, SyntaxTokenType>> = DEFAULT_TOKENS,
) : SyntaxTokenSource {
  @Volatile
  var calls = 0
    private set

  override fun tokenize(
    code: String,
    language: String,
  ): IntArray {
    calls++
    if (language != LANGUAGE) return IntArray(0)
    var from = 0
    return tokens
      .flatMap { (text, type) ->
        val start = code.indexOf(text, from)
        if (start < 0) return@flatMap emptyList()
        from = start + text.length
        listOf(start, start + text.length, type.ordinal)
      }.toIntArray()
  }

  companion object {
    const val LANGUAGE = "python"
    const val CODE = "def greet(name):\n    return \"hi \" + name  # say hi\n"

    val DEFAULT_TOKENS =
      listOf(
        "def" to SyntaxTokenType.KEYWORD,
        "greet" to SyntaxTokenType.FUNCTION,
        "return" to SyntaxTokenType.KEYWORD,
        "\"hi \"" to SyntaxTokenType.STRING,
        "+" to SyntaxTokenType.OPERATOR,
        "# say hi" to SyntaxTokenType.COMMENT,
      )
  }
}
