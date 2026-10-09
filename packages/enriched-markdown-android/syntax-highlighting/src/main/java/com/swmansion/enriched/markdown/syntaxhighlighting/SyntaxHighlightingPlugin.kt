@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.syntaxhighlighting

import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.MarkdownPlugin
import com.swmansion.enriched.markdown.plugin.PluginRegistry

/**
 * Tree-sitter syntax highlighting for fenced code blocks, by the fence's language. Enable it for a
 * Compose subtree with a scope, or pass it to a view directly:
 *
 * ```
 * SyntaxHighlightingPlugin {
 *   EnrichedMarkdownText(markdown)
 * }
 *
 * markdownView.setPlugins(listOf(SyntaxHighlightingPlugin))
 * ```
 *
 * Bash, C, CSS, Go, HTML, Java, JavaScript, JSON, Markdown, Python, Rust, TSX, TypeScript and YAML
 * are highlighted, under their usual aliases (`js`, `py`, `sh`, ...). Any other language, and a
 * fence without one, renders exactly as it does without the plugin. Colors come from
 * [SyntaxHighlightStyle]; only foreground colors change, so a block measures the same either way.
 */
object SyntaxHighlightingPlugin : MarkdownPlugin {
  const val ID = "com.swmansion.enriched.markdown.syntaxhighlighting"

  override val id: String = ID

  // One cache for the process, shared by every view this plugin is enabled for.
  private val decorator = SyntaxHighlightDecorator(SyntaxTokenCache(NativeSyntaxTokenSource))

  override fun install(registry: PluginRegistry) {
    registry.registerCodeBlockDecorator(decorator)
  }
}
