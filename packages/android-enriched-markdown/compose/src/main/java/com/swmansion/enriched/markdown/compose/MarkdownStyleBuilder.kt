package com.swmansion.enriched.markdown.compose

@MarkdownStyleDsl
class MarkdownStyleBuilder internal constructor() {
  private var paragraph: TextStylePatch? = null
  private val headingPatches = mutableMapOf<Int, TextStylePatch>()
  private var link: LinkStylePatch? = null
  private var strong: StrongStylePatch? = null
  private var emphasis: EmphasisStylePatch? = null
  private var superscript: SuperscriptStylePatch? = null
  private var subscript: SubscriptStylePatch? = null
  private var code: CodeStylePatch? = null
  private var codeBlock: CodeBlockStylePatch? = null
  private var blockquote: BlockquoteStylePatch? = null
  private var list: ListStylePatch? = null
  private var image: ImageStylePatch? = null
  private var inlineImage: InlineImageStylePatch? = null
  private var thematicBreak: ThematicBreakStylePatch? = null

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

  fun image(block: ImageStyleScope.() -> Unit) {
    image = ImageStyleScope.merge(image, block)
  }

  fun inlineImage(block: InlineImageStyleScope.() -> Unit) {
    inlineImage = InlineImageStyleScope.merge(inlineImage, block)
  }

  fun thematicBreak(block: ThematicBreakStyleScope.() -> Unit) {
    thematicBreak = ThematicBreakStyleScope.merge(thematicBreak, block)
  }

  internal fun captureLayer(): MarkdownStyleLayer =
    MarkdownStyleLayer(
      paragraph = paragraph,
      headingPatches = headingPatches.toMap(),
      link = link,
      strong = strong,
      emphasis = emphasis,
      superscript = superscript,
      subscript = subscript,
      code = code,
      codeBlock = codeBlock,
      blockquote = blockquote,
      list = list,
      image = image,
      inlineImage = inlineImage,
      thematicBreak = thematicBreak,
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
