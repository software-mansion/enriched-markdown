package com.swmansion.enriched.markdown.renderer

import android.text.SpannableStringBuilder
import android.text.TextPaint
import android.text.TextUtils
import android.text.style.CharacterStyle
import android.text.style.ReplacementSpan
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.LinkFontSpan
import com.swmansion.enriched.markdown.spans.LinkIconSpan
import com.swmansion.enriched.markdown.spans.LinkPillSpan
import com.swmansion.enriched.markdown.spans.LinkSpan
import com.swmansion.enriched.markdown.spans.SpoilerSpan
import com.swmansion.enriched.markdown.utils.common.layout.isLayoutRTL
import com.swmansion.enriched.markdown.utils.text.extensions.applyBlockStyleFont
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import java.lang.ref.WeakReference
import java.text.BreakIterator
import kotlin.math.max
import kotlin.math.min

// The icon and the word it covers are one unbreakable unit, capped at this many font sizes wide
// so the unit still fits a narrow line (a nested list, a large font scale); the rest of a longer
// word wraps as text.
private const val MAX_ICON_RUN_EMS = 8f

class LinkRenderer(
  private val config: RendererConfig,
) : NodeRenderer {
  // Reused to resolve each pill's typeface; a renderer serves one render at a time.
  private val fontProbe = TextPaint()

  // Reused by [iconRunEnd], for the same reason.
  private val characterBreaks = BreakIterator.getCharacterInstance()
  private val lineBreaks = BreakIterator.getLineInstance()
  private val iconRunPaint = TextPaint()

  // The last paragraph checked for right-to-left text, so icon links sharing a paragraph scan it
  // once. The rendered text is a new builder every render, which keeps the result from going stale.
  private var checkedText: WeakReference<CharSequence>? = null
  private var checkedStart = 0
  private var checkedEnd = 0
  private var checkedRightToLeft = false
  private var checkedFirstLeftToRight = -1
  private var checkedLastLeftToRight = -1

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
          builder.setSpan(
            icon,
            iconStart,
            iconRunEnd(builder, iconStart, end, linkSpan, blockStyle.fontSize),
            SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
          )
          factory.runAfterRender {
            val iconSpanStart = builder.getSpanStart(icon)
            if (iconSpanStart < 0) return@runAfterRender
            // Deferred spans (superscript) are in place only now, and their edges end the icon too.
            val iconSpanEnd = iconRunEnd(builder, iconSpanStart, builder.getSpanEnd(linkSpan), linkSpan, blockStyle.fontSize)
            if (!keepsParagraphDirection(builder, iconSpanStart, iconSpanEnd, factory.context.resources.isLayoutRTL())) {
              builder.removeSpan(icon)
              return@runAfterRender
            }
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
   * changes, since a replacement is measured once per run and drawn with one paint, and once the
   * icon and the covered text would be wider than [MAX_ICON_RUN_EMS] font sizes, so a long
   * unbroken token still wraps.
   */
  internal fun iconRunEnd(
    builder: SpannableStringBuilder,
    start: Int,
    end: Int,
    link: LinkSpan,
    fontSize: Float,
  ): Int {
    val text = builder.subSequence(start, end).toString()
    characterBreaks.setText(text)
    lineBreaks.setText(text)
    val firstCharacter = characterBreaks.following(0).takeIf { it != BreakIterator.DONE } ?: text.length
    var wordEnd = lineBreaks.following(0).takeIf { it != BreakIterator.DONE } ?: text.length
    while (wordEnd > firstCharacter && text[wordEnd - 1].isWhitespace()) wordEnd--
    var runEnd = min(wordEnd, builder.nextSpanTransition(start, end, CharacterStyle::class.java) - start)
    if (runEnd > firstCharacter && !characterBreaks.isBoundary(runEnd)) runEnd = characterBreaks.preceding(runEnd)
    val paint =
      iconRunPaint.apply {
        reset()
        textSize = fontSize
        link.applyLinkFont(this)
      }
    val textBudget = fontSize * (MAX_ICON_RUN_EMS - LinkIconSpan.ICON_SLOT_RATIO)
    // One pass over the run, not a measure per character: a long unbroken token is this feature's case.
    val fits = if (runEnd > firstCharacter) paint.breakText(text, 0, runEnd, true, textBudget, null) else runEnd
    if (fits < runEnd) {
      runEnd = if (fits <= firstCharacter || characterBreaks.isBoundary(fits)) fits else characterBreaks.preceding(fits)
    }
    return start + max(firstCharacter, runEnd)
  }

  /**
   * Bidi layout reads a replacement span as a neutral character, so in a paragraph with
   * right-to-left text the covered word could move. Without a left-to-right letter outside
   * [start, end), the paragraph would also take its direction from the device: right to left on
   * [rightToLeftDevice]. In both cases the link keeps its text without the icon.
   */
  private fun keepsParagraphDirection(
    text: CharSequence,
    start: Int,
    end: Int,
    rightToLeftDevice: Boolean,
  ): Boolean {
    if (checkedText?.get() !== text || start < checkedStart || start >= checkedEnd) scanParagraph(text, start)
    if (checkedRightToLeft) return false
    return !rightToLeftDevice || (checkedFirstLeftToRight in 0 until start) || checkedLastLeftToRight >= end
  }

  private fun scanParagraph(
    text: CharSequence,
    position: Int,
  ) {
    var start = position
    while (start > 0 && text[start - 1] != '\n') start--
    val end = TextUtils.indexOf(text, '\n', position).takeIf { it >= 0 } ?: text.length
    var rightToLeft = false
    var firstLeftToRight = -1
    var lastLeftToRight = -1
    var index = start
    while (index < end && !rightToLeft) {
      val codePoint = Character.codePointAt(text, index)
      when (Character.getDirectionality(codePoint)) {
        Character.DIRECTIONALITY_RIGHT_TO_LEFT, Character.DIRECTIONALITY_RIGHT_TO_LEFT_ARABIC -> {
          rightToLeft = true
        }

        Character.DIRECTIONALITY_LEFT_TO_RIGHT -> {
          if (firstLeftToRight < 0) firstLeftToRight = index
          lastLeftToRight = index
        }
      }
      index += Character.charCount(codePoint)
    }
    checkedText = WeakReference(text)
    checkedStart = start
    checkedEnd = end
    checkedRightToLeft = rightToLeft
    checkedFirstLeftToRight = firstLeftToRight
    checkedLastLeftToRight = lastLeftToRight
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
