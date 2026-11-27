@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.segments

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.text.SpannableStringBuilder
import android.text.TextPaint
import android.text.TextUtils
import android.util.TypedValue
import android.view.MotionEvent
import android.view.TouchDelegate
import android.view.View
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.ImageView
import androidx.appcompat.widget.AppCompatImageButton
import androidx.appcompat.widget.AppCompatTextView
import com.swmansion.enriched.markdown.CodeBlockCopy
import com.swmansion.enriched.markdown.CodeBlockLayout
import com.swmansion.enriched.markdown.parser.CodeBlockLanguages
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.plugin.CodeBlockDecorator
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.spans.LineHeightSpan
import com.swmansion.enriched.markdown.styles.CodeBlockStyle
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.text.TypefaceUtils
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import com.swmansion.enriched.markdown.utils.text.view.SelectionMenuConfig
import com.swmansion.enriched.markdown.views.ContextMenuPopup
import com.swmansion.enriched.markdown.views.CopyGlyph
import kotlin.math.ceil
import kotlin.math.roundToInt

/**
 * Block segment view for a root-level fenced code block under [CodeBlockLayout.Scrollable]:
 * a fixed header bar (language name, copy button) above code that never wraps and scrolls
 * horizontally inside the block's box instead. Code blocks nested in a list or blockquote,
 * and every block under [CodeBlockLayout.Wrapping], stay in their text segment, drawn by
 * CodeBlockSpan, and wrap.
 */
class CodeBlockContainerView(
  context: Context,
  private val styleConfig: StyleConfig,
) : FrameLayout(context),
  BlockSegmentView {
  private val codeBlockStyle: CodeBlockStyle = styleConfig.codeBlockStyle

  override val segmentMarginTop: Int get() = codeBlockStyle.marginTop.toInt()
  override val segmentMarginBottom: Int get() = codeBlockStyle.marginBottom.toInt()

  var selectionMenuConfig: SelectionMenuConfig = SelectionMenuConfig()

  /** Called after the copy button or the long-press Copy puts the code on the clipboard; not for Copy as Markdown. */
  var onCodeBlockCopy: ((CodeBlockCopy) -> Unit)? = null

  private val borderWidth = ceil(codeBlockStyle.borderWidth).toInt()
  private val padding = ceil(codeBlockStyle.padding).toInt()

  // Distance from the box edge to the header content.
  private val inset = borderWidth + padding
  private val headerHeight = inset + headerLabelLineHeight(codeBlockStyle)

  private val minTouchTarget = (MIN_TOUCH_TARGET_DP * resources.displayMetrics.density).roundToInt()

  // The copy button grown to minTouchTarget around its center; it reaches over the code's top edge.
  private val copyTouchArea = Rect()

  private var code: String = ""
  private var language: String? = null
  private var fenceChar: Char = '`'

  private val textView =
    AppCompatTextView(context).apply {
      includeFontPadding = false
      setLineSpacing(0f, 1f)
      // Code reads left to right whatever the locale.
      layoutDirection = View.LAYOUT_DIRECTION_LTR
      textDirection = View.TEXT_DIRECTION_LTR
      setTextSize(TypedValue.COMPLEX_UNIT_PX, codeBlockStyle.fontSize)
      typeface = TypefaceUtils.applyStyles(context, codeBlockStyle.fontFamily, codeBlockStyle.fontWeight)
      setTextColor(codeBlockStyle.color)
      setPadding(padding, padding, padding, padding)
      setOnLongClickListener { showContextMenu(it) }
    }

  private val scrollView =
    HorizontalScrollView(context).apply {
      isHorizontalScrollBarEnabled = true
      overScrollMode = View.OVER_SCROLL_NEVER
      layoutDirection = View.LAYOUT_DIRECTION_LTR
      // Short code still fills the box, so a long press anywhere in it lands on the text view;
      // the scroll view itself swallows touches and never reports a long press.
      isFillViewport = true
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        horizontalScrollbarThumbDrawable =
          GradientDrawable().apply {
            setColor(secondaryColor(codeBlockStyle.color))
            cornerRadius = resources.displayMetrics.density * 2
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
      contentDescription = context.getString(android.R.string.copy)
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
          setStroke(borderWidth, codeBlockStyle.borderColor)
        }
      }
    // Scrolled code is clipped to the rounded box rather than drawn over its corners.
    clipToOutline = true
    isLongClickable = true
    setOnLongClickListener { showContextMenu(it) }
    addView(scrollView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
    addView(languageView, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT))
    addView(copyButton, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT))
  }

  /** [text] is what [buildCodeText] made of [node], built off the main thread when it ran decorators. */
  fun applyCodeBlockNode(
    node: MarkdownASTNode,
    text: CharSequence = buildCodeText(node, styleConfig, emptyList(), context),
  ) {
    code = extractCode(node)
    val newLanguage = languageOf(node)
    if (newLanguage != language) {
      language = newLanguage
      languageView.text = CodeBlockLanguages.displayName(newLanguage)
    }
    fenceChar = node.getAttribute("fenceChar")?.firstOrNull() ?: '`'
    textView.text = text
  }

  override fun onMeasure(
    widthSpec: Int,
    heightSpec: Int,
  ) {
    val unspecified = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
    textView.measure(unspecified, unspecified)
    languageView.measure(unspecified, unspecified)
    // The copy button is a headerHeight square at the end of the header.
    val headerWidth = inset * 2 + languageView.measuredWidth + headerHeight
    // The box fills the width it is given; only a wrap_content parent shrinks it to its content.
    val width = resolveSize(maxOf(textView.measuredWidth + borderWidth * 2, headerWidth), widthSpec)
    scrollView.measure(
      MeasureSpec.makeMeasureSpec((width - borderWidth * 2).coerceAtLeast(0), MeasureSpec.EXACTLY),
      unspecified,
    )
    copyButton.measure(
      MeasureSpec.makeMeasureSpec(headerHeight, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(headerHeight, MeasureSpec.EXACTLY),
    )
    languageView.measure(
      MeasureSpec.makeMeasureSpec((width - inset * 2 - headerHeight).coerceAtLeast(0), MeasureSpec.AT_MOST),
      unspecified,
    )
    setMeasuredDimension(width, headerHeight + scrollView.measuredHeight + borderWidth)
  }

  override fun onLayout(
    changed: Boolean,
    left: Int,
    top: Int,
    right: Int,
    bottom: Int,
  ) {
    val width = right - left
    // The header content is centered above the divider, which sits halfway into the code's top padding.
    val headerCenterY = dividerY() / 2f
    val labelTop = (headerCenterY - languageView.measuredHeight / 2f).roundToInt()
    languageView.layout(inset, labelTop, inset + languageView.measuredWidth, labelTop + languageView.measuredHeight)

    // The button is wider than its icon; the icon, not the button, lines up with the content inset.
    val iconWidth = copyButton.drawable?.intrinsicWidth ?: copyButton.measuredWidth
    val iconSlack = ((copyButton.measuredWidth - iconWidth) / 2).coerceAtLeast(0)
    val buttonLeft = (width - inset - copyButton.measuredWidth + iconSlack).coerceAtLeast(0)
    val buttonTop = (headerCenterY - copyButton.measuredHeight / 2f).roundToInt().coerceAtLeast(0)
    copyButton.layout(buttonLeft, buttonTop, buttonLeft + copyButton.measuredWidth, buttonTop + copyButton.measuredHeight)
    updateCopyTouchArea()

    // Inside the border, so scrolled code never paints over it.
    scrollView.layout(borderWidth, headerHeight, width - borderWidth, bottom - top - borderWidth)
  }

  // Divider between the header and the code, drawn in the gap the code's top
  // padding leaves, so it adds no height of its own.
  override fun onDraw(canvas: Canvas) {
    super.onDraw(canvas)
    val y = dividerY()
    canvas.drawLine(borderWidth.toFloat(), y, (width - borderWidth).toFloat(), y, dividerPaint)
  }

  private fun dividerY(): Float = headerHeight + padding / 2f

  private fun updateCopyTouchArea() {
    copyTouchArea.set(copyButton.left, copyButton.top, copyButton.right, copyButton.bottom)
    copyTouchArea.inset(
      -((minTouchTarget - copyTouchArea.width()) / 2).coerceAtLeast(0),
      -((minTouchTarget - copyTouchArea.height()) / 2).coerceAtLeast(0),
    )
    touchDelegate = TouchDelegate(Rect(copyTouchArea), copyButton)
  }

  // The touch delegate only sees touches no child takes, and the scroll view takes every touch
  // on the code, so a press in the grown area is claimed before it reaches the code.
  override fun onInterceptTouchEvent(event: MotionEvent): Boolean =
    (event.actionMasked == MotionEvent.ACTION_DOWN && copyTouchArea.contains(event.x.toInt(), event.y.toInt())) ||
      super.onInterceptTouchEvent(event)

  private fun showContextMenu(anchor: View): Boolean {
    ContextMenuPopup.show(anchor, this) {
      item(ContextMenuPopup.Icon.COPY, context.getString(android.R.string.copy)) { copyCode() }
      if (selectionMenuConfig.copyAsMarkdown) {
        item(ContextMenuPopup.Icon.DOCUMENT, selectionMenuConfig.resolvedCopyAsMarkdownLabel) { copyFencedMarkdown() }
      }
    }
    return true
  }

  // An empty block leaves the clipboard as it was rather than clearing it.
  private fun copyCode() {
    if (code.isEmpty()) return
    copyToClipboard(code)
    onCodeBlockCopy?.invoke(CodeBlockCopy(code, language))
  }

  private fun copyFencedMarkdown() {
    if (code.isEmpty()) return
    copyToClipboard(fencedMarkdown(code, language, fenceChar))
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

  internal companion object {
    private const val HEADER_LABEL_SCALE = 0.85f

    // Drawable box for the copy glyph, as a multiple of the code font size,
    // matching the React Native package's header.
    private const val HEADER_ICON_SCALE = 1.08f

    // Material's minimum touch target; iOS's copy button grows its hit area to 44 pt the same way.
    private const val MIN_TOUCH_TARGET_DP = 48

    private val headerTypeface: Typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)

    private fun secondaryColor(color: Int): Int = (color and 0x00FFFFFF) or (0x99 shl 24)

    private fun dividerColor(color: Int): Int = (color and 0x00FFFFFF) or (0x33 shl 24)

    private fun headerLabelLineHeight(style: CodeBlockStyle): Int {
      val paint =
        TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
          textSize = style.fontSize * HEADER_LABEL_SCALE
          typeface = headerTypeface
        }
      val metrics = paint.fontMetrics
      return ceil(metrics.descent - metrics.ascent).toInt()
    }

    fun extractCode(node: MarkdownASTNode): String {
      val builder = StringBuilder()

      fun append(current: MarkdownASTNode) {
        builder.append(current.content)
        current.children.forEach { append(it) }
      }
      append(node)
      return builder.toString().trimEnd('\n')
    }

    /** The fence outgrows the longest run of [fenceChar] in [code], so the code cannot close it early. */
    fun fencedMarkdown(
      code: String,
      language: String?,
      fenceChar: Char,
    ): String {
      val longestRun =
        Regex("${Regex.escape(fenceChar.toString())}+").findAll(code).maxOfOrNull { it.value.length } ?: 0
      val fence = fenceChar.toString().repeat(maxOf(3, longestRun + 1))
      return "$fence${language.orEmpty()}\n$code\n$fence"
    }

    fun languageOf(node: MarkdownASTNode): String? = node.getAttribute("language")?.takeIf { it.isNotBlank() }

    /**
     * The block's code as the view displays it. [decorators] run here as they do in core's code
     * block renderer for nested blocks, so this is meant for the render thread.
     */
    fun buildCodeText(
      node: MarkdownASTNode,
      style: StyleConfig,
      decorators: List<CodeBlockDecorator>,
      context: Context,
    ): SpannableStringBuilder =
      SpannableStringBuilder(extractCode(node)).apply {
        val lineHeight = style.codeBlockStyle.lineHeight
        if (lineHeight > 0f && isNotEmpty()) {
          setSpan(LineHeightSpan(lineHeight), 0, length, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
        }
        // The text view paints the block's color, so a decorator's color spans override it.
        val language = languageOf(node)
        for (decorator in decorators) {
          decorator.decorate(this, 0, length, language, style, context)
        }
      }
  }
}
