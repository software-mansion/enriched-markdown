package com.swmansion.enriched.markdown.renderer

import android.text.SpannableStringBuilder
import android.text.TextPaint
import android.text.style.CharacterStyle
import android.text.style.ReplacementSpan
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.LinkFontSpan
import com.swmansion.enriched.markdown.spans.LinkIconSpan
import com.swmansion.enriched.markdown.spans.LinkPillSpan
import com.swmansion.enriched.markdown.spans.LinkSpan
import com.swmansion.enriched.markdown.spans.SpoilerSpan
import com.swmansion.enriched.markdown.utils.text.extensions.applyBlockStyleFont
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import java.text.BreakIterator
import kotlin.math.max
import kotlin.math.min

private const val MAX_ICON_RUN = 24

class LinkRenderer(
  private val config: RendererConfig,
) : NodeRenderer {
  // Reused to resolve each pill's typeface; a renderer serves one render at a time.
  private val fontProbe = TextPaint()

  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    val url = node.getAttribute("url") ?: return
    val recognizedLink = node.getAttribute("recognizedLink") == "true"

    factory.renderWithSpan(builder, { factory.renderChildren(node, builder, onLinkPress, onLinkLongPress) }) { start, end, blockStyle ->
      val variant = factory.styleCache.resolvedVariantForUrl(url)
      val inlineIcon = variant?.inlineIcon?.takeIf { builder.getSpans(start, end, ReplacementSpan::class.java).isEmpty() }
      val linkSpan =
        LinkSpan(
          url,
          onLinkPress,
          onLinkLongPress,
          factory.styleCache,
          blockStyle,
          factory.context,
          recognizedLink = recognizedLink,
          keepsCodeFont = recognizedLink && node.children.any { it.type == MarkdownASTNode.NodeType.Code },
          appliesFont = inlineIcon == null,
        )
      if (variant?.pill != null && canPresentAsPill(builder, factory, start, end)) {
        val fontFamily = variant.fontFamily.ifEmpty { factory.styleCache.linkFontFamily }.ifEmpty { blockStyle.fontFamily }
        val font = fontProbe.apply { applyBlockStyleFont(blockStyle.copy(fontFamily = fontFamily), factory.context) }
        val pill =
          LinkPillSpan(
            variant,
            font.typeface,
            blockStyle.fontSize,
            builder.subSequence(start, end).toString(),
            factory.context,
            config.style.linkPillContent[url],
            config.style.imageRequestHeaders,
            followsRunTypeface = variant.fontFamily.isEmpty() && factory.styleCache.linkFontFamily.isEmpty(),
          )
        // Set directly, not deferred: the pill measures with its own font, so it does not
        // need to come after the block spans, and a late insertion makes the builder re-sort.
        builder.setSpan(pill, start, end, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
        factory.runAfterRender { text -> pill.resolveLeadingMargin(text, text.getSpanStart(pill), text.getSpanEnd(pill)) }
      } else if (inlineIcon != null) {
        // The link font is applied while measuring, not only while drawing, so the text wraps where it
        // is drawn. Set after the children's spans: their fonts lose to the link's, an enclosing
        // bold or italic set later still applies.
        builder.setSpan(LinkFontSpan(linkSpan), start, end, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
        // Leading whitespace can sit in a run of its own (a soft line break), and a replacement
        // spanning two runs is drawn once per run, so the icon starts at the first visible character.
        val iconStart = (start until end).firstOrNull { !builder[it].isWhitespace() }
        if (iconStart != null) {
          val icon = LinkIconSpan(inlineIcon, linkSpan, blockStyle.fontSize, factory.context, config.style.imageRequestHeaders)
          builder.setSpan(icon, iconStart, iconRunEnd(builder, iconStart, end), SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
          factory.runAfterRender {
            val iconSpanStart = builder.getSpanStart(icon)
            if (iconSpanStart < 0) return@runAfterRender
            // Bidi layout treats a replacement span as neutral, so in a paragraph with right-to-left
            // text the covered word could move, or set the paragraph's direction. There the link
            // keeps its text without the icon.
            if (paragraphHasRightToLeft(builder, iconSpanStart)) {
              builder.removeSpan(icon)
              return@runAfterRender
            }
            // Deferred spans (superscript) are in place only now, and their edges end the icon too.
            val iconSpanEnd = iconRunEnd(builder, iconSpanStart, builder.getSpanEnd(linkSpan))
            if (iconSpanEnd != builder.getSpanEnd(icon)) builder.setSpan(icon, iconSpanStart, iconSpanEnd, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
          }
        }
      }
      builder.setSpan(linkSpan, start, end, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
    }
  }

  /**
   * Where the icon span that starts at [start] ends: the first point the line may break, so the
   * icon stays with its first word. A line can break on either side of a replacement span, so
   * covering less would let that word split after its first letter. Stops where any text style
   * changes, since a replacement is measured once per run and drawn with one paint, and after
   * [MAX_ICON_RUN] characters, so a long unbroken token still wraps.
   */
  private fun iconRunEnd(
    builder: SpannableStringBuilder,
    start: Int,
    end: Int,
  ): Int {
    val text = builder.subSequence(start, end).toString()
    val characters = BreakIterator.getCharacterInstance().apply { setText(text) }
    val firstCharacter = characters.following(0).takeIf { it != BreakIterator.DONE } ?: text.length
    val lines = BreakIterator.getLineInstance().apply { setText(text) }
    var wordEnd = lines.following(0).takeIf { it != BreakIterator.DONE } ?: text.length
    while (wordEnd > firstCharacter && text[wordEnd - 1].isWhitespace()) wordEnd--
    val limit = min(builder.nextSpanTransition(start, end, CharacterStyle::class.java) - start, MAX_ICON_RUN)
    var runEnd = min(wordEnd, limit)
    if (runEnd > firstCharacter && !characters.isBoundary(runEnd)) runEnd = characters.preceding(runEnd)
    return start + max(firstCharacter, runEnd)
  }

  private fun paragraphHasRightToLeft(
    text: CharSequence,
    position: Int,
  ): Boolean {
    if (position < 0) return false
    var index = position
    while (index > 0 && text[index - 1] != '\n') index--
    while (index < text.length && text[index] != '\n') {
      val codePoint = Character.codePointAt(text, index)
      when (Character.getDirectionality(codePoint)) {
        Character.DIRECTIONALITY_RIGHT_TO_LEFT, Character.DIRECTIONALITY_RIGHT_TO_LEFT_ARABIC -> return true
      }
      index += Character.charCount(codePoint)
    }
    return false
  }

  /**
   * A pill replaces one unbroken run. Links that already hold a replacement (image,
   * math) or span a line break stay ordinary links: a replacement straddling two
   * paragraphs would be drawn once per paragraph. So do links holding a spoiler,
   * whose hidden text the label would show.
   */
  private fun canPresentAsPill(
    builder: SpannableStringBuilder,
    factory: RendererFactory,
    start: Int,
    end: Int,
  ): Boolean {
    if (builder.getSpans(start, end, ReplacementSpan::class.java).isNotEmpty()) return false
    // Spoiler spans are deferred, so the ones inside this link are not in the builder yet.
    if (factory.hasDeferredSpan(SpoilerSpan::class.java, start, end)) return false
    for (index in start until end) {
      val char = builder[index]
      if (char == '\n' || char == '\r' || char == '\u2028' || char == '\u2029') return false
    }
    return true
  }
}
