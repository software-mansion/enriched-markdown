package com.swmansion.enriched.markdown.compose

import com.swmansion.enriched.markdown.compose.patches.BlockquoteStylePatch
import com.swmansion.enriched.markdown.compose.patches.BlockquoteStyleScope
import com.swmansion.enriched.markdown.compose.patches.CodeBlockStylePatch
import com.swmansion.enriched.markdown.compose.patches.CodeBlockStyleScope
import com.swmansion.enriched.markdown.compose.patches.CodeStylePatch
import com.swmansion.enriched.markdown.compose.patches.CodeStyleScope
import com.swmansion.enriched.markdown.compose.patches.EmphasisStylePatch
import com.swmansion.enriched.markdown.compose.patches.EmphasisStyleScope
import com.swmansion.enriched.markdown.compose.patches.HeadingStyleScope
import com.swmansion.enriched.markdown.compose.patches.HighlightStylePatch
import com.swmansion.enriched.markdown.compose.patches.HighlightStyleScope
import com.swmansion.enriched.markdown.compose.patches.ImageStylePatch
import com.swmansion.enriched.markdown.compose.patches.ImageStyleScope
import com.swmansion.enriched.markdown.compose.patches.InlineImageStylePatch
import com.swmansion.enriched.markdown.compose.patches.InlineImageStyleScope
import com.swmansion.enriched.markdown.compose.patches.LinkStylePatch
import com.swmansion.enriched.markdown.compose.patches.LinkStyleScope
import com.swmansion.enriched.markdown.compose.patches.ListStylePatch
import com.swmansion.enriched.markdown.compose.patches.ListStyleScope
import com.swmansion.enriched.markdown.compose.patches.ParagraphStyleScope
import com.swmansion.enriched.markdown.compose.patches.SpoilerStylePatch
import com.swmansion.enriched.markdown.compose.patches.SpoilerStyleScope
import com.swmansion.enriched.markdown.compose.patches.StrikethroughStylePatch
import com.swmansion.enriched.markdown.compose.patches.StrikethroughStyleScope
import com.swmansion.enriched.markdown.compose.patches.StrongStylePatch
import com.swmansion.enriched.markdown.compose.patches.StrongStyleScope
import com.swmansion.enriched.markdown.compose.patches.SubscriptStylePatch
import com.swmansion.enriched.markdown.compose.patches.SubscriptStyleScope
import com.swmansion.enriched.markdown.compose.patches.SuperscriptStylePatch
import com.swmansion.enriched.markdown.compose.patches.SuperscriptStyleScope
import com.swmansion.enriched.markdown.compose.patches.TableStylePatch
import com.swmansion.enriched.markdown.compose.patches.TableStyleScope
import com.swmansion.enriched.markdown.compose.patches.TaskListStylePatch
import com.swmansion.enriched.markdown.compose.patches.TaskListStyleScope
import com.swmansion.enriched.markdown.compose.patches.TextStylePatch
import com.swmansion.enriched.markdown.compose.patches.TextStyleScope
import com.swmansion.enriched.markdown.compose.patches.ThematicBreakStylePatch
import com.swmansion.enriched.markdown.compose.patches.ThematicBreakStyleScope
import com.swmansion.enriched.markdown.compose.patches.UnderlineStylePatch
import com.swmansion.enriched.markdown.compose.patches.UnderlineStyleScope

@MarkdownStyleDsl
class MarkdownStyleBuilder internal constructor() {
  private var paragraph: TextStylePatch? = null
  private val headingPatches = mutableMapOf<Int, TextStylePatch>()
  private var link: LinkStylePatch? = null
  private var strong: StrongStylePatch? = null
  private var emphasis: EmphasisStylePatch? = null
  private var strikethrough: StrikethroughStylePatch? = null
  private var underline: UnderlineStylePatch? = null
  private var highlight: HighlightStylePatch? = null
  private var superscript: SuperscriptStylePatch? = null
  private var subscript: SubscriptStylePatch? = null
  private var code: CodeStylePatch? = null
  private var codeBlock: CodeBlockStylePatch? = null
  private var blockquote: BlockquoteStylePatch? = null
  private var list: ListStylePatch? = null
  private var taskList: TaskListStylePatch? = null
  private var image: ImageStylePatch? = null
  private var inlineImage: InlineImageStylePatch? = null
  private var thematicBreak: ThematicBreakStylePatch? = null
  private var table: TableStylePatch? = null
  private var spoiler: SpoilerStylePatch? = null

  fun paragraph(block: ParagraphStyleScope.() -> Unit) {
    paragraph = TextStyleScope.merge(paragraph, block)
  }

  fun h1(block: HeadingStyleScope.() -> Unit) = heading(1, block)

  fun h2(block: HeadingStyleScope.() -> Unit) = heading(2, block)

  fun h3(block: HeadingStyleScope.() -> Unit) = heading(3, block)

  fun h4(block: HeadingStyleScope.() -> Unit) = heading(4, block)

  fun h5(block: HeadingStyleScope.() -> Unit) = heading(5, block)

  fun h6(block: HeadingStyleScope.() -> Unit) = heading(6, block)

  fun link(block: LinkStyleScope.() -> Unit) {
    link = LinkStyleScope.merge(link, block)
  }

  fun strong(block: StrongStyleScope.() -> Unit) {
    strong = StrongStyleScope.merge(strong, block)
  }

  fun emphasis(block: EmphasisStyleScope.() -> Unit) {
    emphasis = EmphasisStyleScope.merge(emphasis, block)
  }

  fun strikethrough(block: StrikethroughStyleScope.() -> Unit) {
    strikethrough = StrikethroughStyleScope.merge(strikethrough, block)
  }

  fun underline(block: UnderlineStyleScope.() -> Unit) {
    underline = UnderlineStyleScope.merge(underline, block)
  }

  fun highlight(block: HighlightStyleScope.() -> Unit) {
    highlight = HighlightStyleScope.merge(highlight, block)
  }

  fun superscript(block: SuperscriptStyleScope.() -> Unit) {
    superscript = SuperscriptStyleScope.merge(superscript, block)
  }

  fun subscript(block: SubscriptStyleScope.() -> Unit) {
    subscript = SubscriptStyleScope.merge(subscript, block)
  }

  fun code(block: CodeStyleScope.() -> Unit) {
    code = CodeStyleScope.merge(code, block)
  }

  fun codeBlock(block: CodeBlockStyleScope.() -> Unit) {
    codeBlock = CodeBlockStyleScope.merge(codeBlock, block)
  }

  fun blockquote(block: BlockquoteStyleScope.() -> Unit) {
    blockquote = BlockquoteStyleScope.merge(blockquote, block)
  }

  fun list(block: ListStyleScope.() -> Unit) {
    list = ListStyleScope.merge(list, block)
  }

  fun taskList(block: TaskListStyleScope.() -> Unit) {
    taskList = TaskListStyleScope.merge(taskList, block)
  }

  fun image(block: ImageStyleScope.() -> Unit) {
    image = ImageStyleScope.merge(image, block)
  }

  fun inlineImage(block: InlineImageStyleScope.() -> Unit) {
    inlineImage = InlineImageStyleScope.merge(inlineImage, block)
  }

  fun thematicBreak(block: ThematicBreakStyleScope.() -> Unit) {
    thematicBreak = ThematicBreakStyleScope.merge(thematicBreak, block)
  }

  fun table(block: TableStyleScope.() -> Unit) {
    table = TableStyleScope.merge(table, block)
  }

  /** Styling of the overlay that conceals `||spoiler||` text until it is tapped. */
  fun spoiler(block: SpoilerStyleScope.() -> Unit) {
    spoiler = SpoilerStyleScope.merge(spoiler, block)
  }

  internal fun captureLayer(): MarkdownStyleLayer =
    MarkdownStyleLayer(
      paragraph = paragraph,
      headingPatches = headingPatches.toMap(),
      link = link,
      strong = strong,
      emphasis = emphasis,
      strikethrough = strikethrough,
      underline = underline,
      highlight = highlight,
      superscript = superscript,
      subscript = subscript,
      code = code,
      codeBlock = codeBlock,
      blockquote = blockquote,
      list = list,
      taskList = taskList,
      image = image,
      inlineImage = inlineImage,
      thematicBreak = thematicBreak,
      table = table,
      spoiler = spoiler,
    )

  private fun heading(
    level: Int,
    block: HeadingStyleScope.() -> Unit,
  ) {
    headingPatches[level] = TextStyleScope.merge(headingPatches[level], block)
  }
}

/**
 * Creates a [MarkdownStyle] using Compose types (`Color`, `Dp`, `sp`, [androidx.compose.ui.text.font.FontFamily]).
 *
 * Call from a `@Composable` to read [androidx.compose.material3.MaterialTheme] tokens:
 *
 * ```
 * MaterialTheme {
 *   MarkdownTheme(style = markdownStyle {
 *     paragraph { color = MaterialTheme.colorScheme.onSurface }
 *     link { color = MaterialTheme.colorScheme.primary }
 *   }) {
 *     NavHost(...)
 *   }
 * }
 * ```
 *
 * For styles that track Material color-scheme changes automatically, prefer [rememberMarkdownStyle].
 */
fun markdownStyle(block: MarkdownStyleBuilder.() -> Unit): MarkdownStyle =
  MarkdownStyle(listOf(MarkdownStyleBuilder().apply(block).captureLayer()))
