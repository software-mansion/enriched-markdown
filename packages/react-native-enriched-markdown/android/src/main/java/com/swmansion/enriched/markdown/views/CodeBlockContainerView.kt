package com.swmansion.enriched.markdown.views

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.text.Layout
import android.text.SpannableString
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.util.TypedValue
import android.view.View
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.ImageView
import androidx.appcompat.widget.AppCompatImageButton
import androidx.appcompat.widget.AppCompatTextView
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.LineHeightSpan
import com.swmansion.enriched.markdown.styles.CodeBlockStyle
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.common.CodeBlockHighlighter
import com.swmansion.enriched.markdown.utils.common.CodeBlockNode
import com.swmansion.enriched.markdown.utils.text.extensions.applyCodeBlockTextStyle
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import kotlin.math.ceil

/**
 * Block segment view for fenced code blocks (see splitASTIntoSegments):
 * a fixed header bar (language name, copy button) above a horizontally
 * scrolling, non-wrapping code pane. Syntax coloring comes from the
 * CodeBlockHighlighter seam and falls back to plain text. The box visuals
 * must stay in sync with the commonmark flavor's CodeBlockSpan.
 *
 * measureCodeBlockNodeHeight must stay in sync with the view: it builds the
 * same styled text, paint, and header metrics, so the height reported to
 * Yoga matches the laid-out height. Since lines never wrap, the height is
 * independent of the available width.
 */
class CodeBlockContainerView(
  context: Context,
  styleConfig: StyleConfig,
) : FrameLayout(context),
  BlockSegmentView {
  private val codeBlockStyle: CodeBlockStyle = styleConfig.codeBlockStyle

  private val inset = contentInset(codeBlockStyle)
  private val borderW = borderPx(codeBlockStyle)
  private val headerH = headerHeight(codeBlockStyle)

  override val segmentMarginTop: Int get() = codeBlockStyle.marginTop.toInt()
  override val segmentMarginBottom: Int get() = codeBlockStyle.marginBottom.toInt()

  var copyLabel: String = ""
    set(value) {
      field = value
      copyButton.contentDescription = value
    }
  var copyAsMarkdownLabel: String = ""

  var onCopyPress: ((code: String, language: String) -> Unit)? = null

  private var code: String = ""
  private var language: String? = null
  private var fenceChar: String = "`"

  // True until the closing fence arrives: highlighting is deferred and copying
  // is disabled, while the header stays visible.
  var pending: Boolean = false
    set(value) {
      if (field == value) return
      field = value
      copyButton.isEnabled = !value
      // The reconciler can reuse an unchanged block without re-applying the
      // node, so re-derive here to pick up highlighting once the block closes.
      rebuildCodeText()
    }

  private val textView =
    AppCompatTextView(context).apply {
      includeFontPadding = false
      setLineSpacing(0f, 1f)
      breakStrategy = Layout.BREAK_STRATEGY_SIMPLE
      hyphenationFrequency = Layout.HYPHENATION_FREQUENCY_NONE
      layoutDirection = View.LAYOUT_DIRECTION_LTR
      textDirection = View.TEXT_DIRECTION_LTR
      setTextSize(TypedValue.COMPLEX_UNIT_PX, codeBlockStyle.fontSize)
      typeface = createCodePaint(codeBlockStyle, context).typeface
      setTextColor(codeBlockStyle.color)
      val horizontalPad = (inset - borderW).coerceAtLeast(0)
      setPadding(horizontalPad, inset, horizontalPad, inset)
      setOnLongClickListener { view -> showContextMenu(view) }
    }

  private val scrollView =
    HorizontalScrollView(context).apply {
      isHorizontalScrollBarEnabled = true
      overScrollMode = View.OVER_SCROLL_NEVER
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        horizontalScrollbarThumbDrawable =
          GradientDrawable().apply {
            setColor(secondaryColor(codeBlockStyle.color))
            cornerRadius = context.resources.displayMetrics.density * 2
          }
      }
      addView(textView, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT))
    }

  private val languageView =
    AppCompatTextView(context).apply {
      includeFontPadding = false
      maxLines = 1
      ellipsize = TextUtils.TruncateAt.END
      setTextSize(TypedValue.COMPLEX_UNIT_PX, codeBlockStyle.fontSize * HEADER_LABEL_SCALE)
      typeface = headerTypeface
      setTextColor(secondaryColor(codeBlockStyle.color))
    }

  private val copyButton =
    AppCompatImageButton(context).apply {
      background = null
      scaleType = ImageView.ScaleType.CENTER
      setImageDrawable(
        CopyIconDrawable(
          secondaryColor(codeBlockStyle.color),
          ceil(codeBlockStyle.fontSize * HEADER_ICON_SCALE).toInt(),
        ),
      )
      setOnClickListener { copyCode() }
    }

  private val dividerPaint =
    Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = dividerColor(codeBlockStyle.color)
      strokeWidth = context.resources.displayMetrics.density
    }

  init {
    setWillNotDraw(false)
    background =
      GradientDrawable().apply {
        setColor(codeBlockStyle.backgroundColor)
        cornerRadius = codeBlockStyle.borderRadius
        if (codeBlockStyle.borderWidth > 0f) {
          setStroke(ceil(codeBlockStyle.borderWidth).toInt(), codeBlockStyle.borderColor)
        }
      }
    isLongClickable = true
    setOnLongClickListener { view -> showContextMenu(view) }
    addView(scrollView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
    addView(languageView, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT))
    addView(copyButton, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT))
  }

  fun applyCodeBlockNode(node: MarkdownASTNode) {
    code = CodeBlockNode.extractCode(node)
    fenceChar = CodeBlockNode.fenceChar(node)

    val newLanguage = CodeBlockNode.language(node)
    if (newLanguage != language) {
      language = newLanguage
      languageView.text = CodeBlockNode.displayLanguageName(newLanguage)
    }

    rebuildCodeText()
  }

  // Highlighting is deferred while pending, applied once the block closes.
  private fun rebuildCodeText() {
    val plainCode = buildCodeText(code, codeBlockStyle)
    if (!pending) {
      CodeBlockHighlighter.highlight(plainCode, code, language, codeBlockStyle)
    }
    textView.text = plainCode
  }

  override fun onMeasure(
    widthSpec: Int,
    heightSpec: Int,
  ) {
    val measuredWidth = MeasureSpec.getSize(widthSpec)
    scrollView.measure(
      MeasureSpec.makeMeasureSpec((measuredWidth - borderW * 2).coerceAtLeast(0), MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED),
    )
    copyButton.measure(
      MeasureSpec.makeMeasureSpec(headerH, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(headerH, MeasureSpec.EXACTLY),
    )
    val labelMaxWidth = (measuredWidth - inset * 2 - headerH).coerceAtLeast(0)
    languageView.measure(
      MeasureSpec.makeMeasureSpec(labelMaxWidth, MeasureSpec.AT_MOST),
      MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED),
    )
    setMeasuredDimension(measuredWidth, headerH + scrollView.measuredHeight)
  }

  override fun onLayout(
    changed: Boolean,
    left: Int,
    top: Int,
    right: Int,
    bottom: Int,
  ) {
    val width = right - left
    val labelTop = headerH - languageView.measuredHeight
    languageView.layout(
      inset,
      labelTop,
      inset + languageView.measuredWidth,
      labelTop + languageView.measuredHeight,
    )

    val iconWidth = copyButton.drawable?.intrinsicWidth ?: copyButton.measuredWidth
    val iconSlack = ((copyButton.measuredWidth - iconWidth) / 2).coerceAtLeast(0)
    val buttonLeft = (width - inset - copyButton.measuredWidth + iconSlack).coerceAtLeast(0)
    val buttonTop = (headerH - languageView.measuredHeight / 2 - copyButton.measuredHeight / 2).coerceAtLeast(0)
    copyButton.layout(
      buttonLeft,
      buttonTop,
      buttonLeft + copyButton.measuredWidth,
      buttonTop + copyButton.measuredHeight,
    )

    scrollView.layout(borderW, headerH, width - borderW, bottom - top - borderW)
  }

  // Divider between the header and the code, centered in the gap the code
  // text's top inset creates, so it adds no height of its own.
  override fun onDraw(canvas: Canvas) {
    super.onDraw(canvas)
    val borderWidth = borderW.toFloat()
    val y = headerH + inset / 2f
    canvas.drawLine(borderWidth, y, width - borderWidth, y, dividerPaint)
  }

  // Returns whether a menu was shown, so the long-press listener only consumes
  // the event when there is one (a pending block has no menu yet).
  private fun showContextMenu(anchor: View): Boolean {
    if (pending) return false
    ContextMenuPopup.show(anchor, this) {
      item(ContextMenuPopup.Icon.COPY, copyLabel) { copyCode() }
      item(ContextMenuPopup.Icon.DOCUMENT, copyAsMarkdownLabel) { copyFencedMarkdown() }
    }
    return true
  }

  private fun copyCode() {
    if (pending || code.isEmpty()) return
    copyToClipboard(code)
    onCopyPress?.invoke(code, language ?: "")
  }

  private fun copyFencedMarkdown() {
    if (code.isEmpty()) return
    copyToClipboard(CodeBlockNode.fencedMarkdown(code, language, fenceChar))
  }

  private fun copyToClipboard(text: String) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    clipboard.setPrimaryClip(ClipData.newPlainText("Code", text))
  }

  private class CopyIconDrawable(
    color: Int,
    private val size: Int,
  ) : Drawable() {
    private val paint =
      Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = size / 20f
        strokeJoin = Paint.Join.ROUND
        strokeCap = Paint.Cap.ROUND
        this.color = color
      }

    private val glyph = CopyGlyph()

    override fun draw(canvas: Canvas) {
      glyph.draw(canvas, bounds.width().toFloat(), paint)
    }

    override fun getIntrinsicWidth() = size

    override fun getIntrinsicHeight() = size

    override fun setAlpha(alpha: Int) {
      paint.alpha = alpha
    }

    override fun setColorFilter(colorFilter: ColorFilter?) {
      paint.colorFilter = colorFilter
    }

    @Deprecated("Deprecated in Java")
    override fun getOpacity() = PixelFormat.TRANSLUCENT
  }

  companion object {
    private const val HEADER_LABEL_SCALE = 0.85f

    // Drawable box for the copy glyph, as a multiple of the code font size.
    // iOS sizes the SF Symbol by point size (kENRMHeaderIconScale = 0.72) but
    // the symbol renders roughly half again as tall as its point size; this box
    // is scaled up to land the drawn glyph at the same on-screen size.
    private const val HEADER_ICON_SCALE = 1.08f

    private val headerTypeface: Typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)

    private fun secondaryColor(color: Int): Int = (color and 0x00FFFFFF) or (0x99 shl 24)

    private fun dividerColor(color: Int): Int = (color and 0x00FFFFFF) or (0x33 shl 24)

    private fun contentInset(style: CodeBlockStyle): Int = ceil(style.padding + style.borderWidth).toInt()

    private fun borderPx(style: CodeBlockStyle): Int = ceil(style.borderWidth).toInt()

    // Header is the top content inset plus one label line; the code text
    // view's own top inset then forms the single gap below the label.
    private fun headerHeight(style: CodeBlockStyle): Int {
      val paint =
        TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
          textSize = style.fontSize * HEADER_LABEL_SCALE
          typeface = headerTypeface
        }
      val metrics = paint.fontMetrics
      return contentInset(style) + ceil(metrics.descent - metrics.ascent).toInt()
    }

    private fun createCodePaint(
      style: CodeBlockStyle,
      context: Context,
    ): TextPaint =
      TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        applyCodeBlockTextStyle(style, context)
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

    // Lines never wrap (the code pane scrolls horizontally), so the layout is
    // built at the text's desired width and the result is independent of the
    // available width.
    fun measureCodeBlockNodeHeight(
      node: MarkdownASTNode,
      config: StyleConfig,
      context: Context,
      @Suppress("unused") width: Float,
    ): Float {
      val style = config.codeBlockStyle
      val inset = contentInset(style)
      val headerH = headerHeight(style)
      val text = buildCodeText(CodeBlockNode.extractCode(node), style)
      if (text.isEmpty()) return headerH + inset * 2f
      val paint = createCodePaint(style, context)
      val contentWidth = ceil(Layout.getDesiredWidth(text, paint)).toInt().coerceAtLeast(1)
      val layout =
        StaticLayout.Builder
          .obtain(text, 0, text.length, paint, contentWidth)
          .setIncludePad(false)
          .setLineSpacing(0f, 1f)
          .setBreakStrategy(Layout.BREAK_STRATEGY_SIMPLE)
          .setHyphenationFrequency(Layout.HYPHENATION_FREQUENCY_NONE)
          .build()
      return layout.height.toFloat() + inset * 2 + headerH
    }
  }
}
