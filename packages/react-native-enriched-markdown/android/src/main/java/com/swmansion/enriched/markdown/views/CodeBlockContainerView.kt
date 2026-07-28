package com.swmansion.enriched.markdown.views

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Paint
import android.graphics.drawable.GradientDrawable
import android.text.Layout
import android.text.SpannableString
import android.text.StaticLayout
import android.text.TextPaint
import android.util.TypedValue
import android.view.View
import android.widget.FrameLayout
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.renderer.BlockStyle
import com.swmansion.enriched.markdown.spans.LineHeightSpan
import com.swmansion.enriched.markdown.styles.CodeBlockStyle
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.common.CodeBlockHighlighter
import com.swmansion.enriched.markdown.utils.text.extensions.applyBlockStyleFont
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import kotlin.math.ceil

/**
 * Block segment view for fenced code blocks, rendered as a sibling view next
 * to text segments the same way TableContainerView is (see splitASTIntoSegments).
 *
 * The view draws the code as a single non-editable text run with the code
 * block background, border, and padding. Long lines wrap, matching the
 * previous span-based rendering (horizontal scrolling can be added later as a
 * style option). Syntax coloring is delegated to the shared C++ highlighting
 * seam through the CodeBlockHighlighter adapter; when the highlighting module
 * is compiled out the code is drawn uncolored, which keeps the block visually
 * equivalent to the old CodeBlockSpan path.
 *
 * Measurement parity: measureCodeBlockNodeHeight builds the same styled text
 * and paint as the view, so the height reported to Yoga at shadow-node
 * measure time matches the height the view lays out with. The text view
 * disables font padding and uses the simple break strategy so its internal
 * layout matches the StaticLayout used for measurement.
 */
class CodeBlockContainerView(
  context: Context,
  styleConfig: StyleConfig,
) : FrameLayout(context),
  BlockSegmentView {
  private val codeBlockStyle: CodeBlockStyle = styleConfig.codeBlockStyle

  override val segmentMarginTop: Int get() = codeBlockStyle.marginTop.toInt()
  override val segmentMarginBottom: Int get() = codeBlockStyle.marginBottom.toInt()

  var copyLabel: String = ""
  var copyAsMarkdownLabel: String = ""

  private var code: String = ""
  private var language: String? = null
  private var fenceChar: String = "`"

  private val textView =
    androidx.appcompat.widget.AppCompatTextView(context).apply {
      includeFontPadding = false
      setLineSpacing(0f, 1f)
      breakStrategy = Layout.BREAK_STRATEGY_SIMPLE
      hyphenationFrequency = Layout.HYPHENATION_FREQUENCY_NONE
      layoutDirection = View.LAYOUT_DIRECTION_LTR
      textDirection = View.TEXT_DIRECTION_LTR
      setTextSize(TypedValue.COMPLEX_UNIT_PX, codeBlockStyle.fontSize)
      typeface = createCodePaint(codeBlockStyle, context).typeface
      setTextColor(codeBlockStyle.color)
      val inset = contentInset(codeBlockStyle)
      setPadding(inset, inset, inset, inset)
      background =
        GradientDrawable().apply {
          setColor(codeBlockStyle.backgroundColor)
          cornerRadius = codeBlockStyle.borderRadius
          if (codeBlockStyle.borderWidth > 0f) {
            setStroke(ceil(codeBlockStyle.borderWidth).toInt(), codeBlockStyle.borderColor)
          }
        }
      setOnLongClickListener { view ->
        showContextMenu(view)
        true
      }
    }

  init {
    addView(textView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
  }

  fun applyCodeBlockNode(node: MarkdownASTNode) {
    code = extractCode(node)
    language = node.getAttribute("language")?.takeIf { it.isNotEmpty() }
    fenceChar = node.getAttribute("fenceChar")?.takeIf { it.isNotEmpty() } ?: "`"

    val plainCode = buildCodeText(code, codeBlockStyle)
    textView.text = CodeBlockHighlighter.highlight(plainCode, code, language) ?: plainCode
  }

  override fun onMeasure(
    widthSpec: Int,
    heightSpec: Int,
  ) {
    val measuredWidth = MeasureSpec.getSize(widthSpec)
    textView.measure(
      MeasureSpec.makeMeasureSpec(measuredWidth, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED),
    )
    setMeasuredDimension(measuredWidth, textView.measuredHeight)
  }

  override fun onLayout(
    changed: Boolean,
    left: Int,
    top: Int,
    right: Int,
    bottom: Int,
  ) {
    textView.layout(0, 0, right - left, bottom - top)
  }

  private fun showContextMenu(anchor: View) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    ContextMenuPopup.show(anchor, this) {
      item(ContextMenuPopup.Icon.COPY, copyLabel) {
        if (code.isNotEmpty()) {
          clipboard.setPrimaryClip(ClipData.newPlainText("Code", code))
        }
      }
      item(ContextMenuPopup.Icon.DOCUMENT, copyAsMarkdownLabel) {
        if (code.isNotEmpty()) {
          clipboard.setPrimaryClip(ClipData.newPlainText("Code", buildFencedMarkdown()))
        }
      }
    }
  }

  private fun buildFencedMarkdown(): String {
    val fence = fenceChar.repeat(3)
    return "$fence${language.orEmpty()}\n$code\n$fence"
  }

  companion object {
    private fun contentInset(style: CodeBlockStyle): Int = ceil(style.padding + style.borderWidth).toInt()

    private fun extractCode(node: MarkdownASTNode): String {
      val builder = StringBuilder()

      fun append(current: MarkdownASTNode) {
        builder.append(current.content)
        current.children.forEach { append(it) }
      }
      append(node)
      return builder.toString().trimEnd('\n')
    }

    private fun createCodePaint(
      style: CodeBlockStyle,
      context: Context,
    ): TextPaint =
      TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = style.fontSize
        applyBlockStyleFont(
          BlockStyle(
            fontSize = style.fontSize,
            fontFamily = style.fontFamily,
            fontWeight = style.fontWeight,
            color = style.color,
          ),
          context,
        )
      }

    private fun buildCodeText(
      code: String,
      style: CodeBlockStyle,
    ): SpannableString =
      SpannableString(code).apply {
        if (style.lineHeight > 0f && isNotEmpty()) {
          setSpan(LineHeightSpan(style.lineHeight), 0, length, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
        }
      }

    fun measureCodeBlockNodeHeight(
      node: MarkdownASTNode,
      config: StyleConfig,
      context: Context,
      width: Float,
    ): Float {
      val style = config.codeBlockStyle
      val inset = contentInset(style)
      val text = buildCodeText(extractCode(node), style)
      if (text.isEmpty()) return inset * 2f
      val contentWidth = (ceil(width).toInt() - inset * 2).coerceAtLeast(1)
      val layout =
        StaticLayout.Builder
          .obtain(text, 0, text.length, createCodePaint(style, context), contentWidth)
          .setIncludePad(false)
          .setLineSpacing(0f, 1f)
          .setBreakStrategy(Layout.BREAK_STRATEGY_SIMPLE)
          .setHyphenationFrequency(Layout.HYPHENATION_FREQUENCY_NONE)
          .build()
      return layout.height.toFloat() + inset * 2
    }
  }
}
