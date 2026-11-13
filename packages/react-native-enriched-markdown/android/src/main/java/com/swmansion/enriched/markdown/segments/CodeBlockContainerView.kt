package com.swmansion.enriched.markdown.segments

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
import android.os.Handler
import android.os.Looper
import android.text.Layout
import android.text.SpannableString
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.util.TypedValue
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.ImageView
import androidx.appcompat.widget.AppCompatImageButton
import androidx.appcompat.widget.AppCompatTextView
import com.swmansion.enriched.markdown.accessibility.AccessibilityLabels
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.LineHeightSpan
import com.swmansion.enriched.markdown.styles.CodeBlockStyle
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.common.CodeBlockHighlighter
import com.swmansion.enriched.markdown.utils.common.CodeBlockNode
import com.swmansion.enriched.markdown.utils.text.extensions.applyCodeBlockTextStyle
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import com.swmansion.enriched.markdown.views.CheckmarkGlyph
import com.swmansion.enriched.markdown.views.ContextMenuPopup
import com.swmansion.enriched.markdown.views.CopyGlyph
import com.swmansion.enriched.markdown.views.WrapGlyph
import kotlin.math.ceil
import kotlin.math.roundToInt

/**
 * Block segment view for fenced code blocks (see splitASTIntoSegments):
 * a fixed header bar (language name, copy button) above a horizontally
 * scrolling, non-wrapping code pane. Syntax coloring comes from the
 * CodeBlockHighlighter seam and falls back to plain text. The box visuals
 * must stay in sync with the commonmark flavor's CodeBlockSpan.
 *
 * measureCodeBlockNodeHeight must stay in sync with the view: it builds the
 * same styled text, paint, and header metrics, so the height reported to
 * Yoga matches the laid-out height. Unless the block is wrapped (the optional
 * header wrap toggle), lines never wrap and the height is independent of the
 * available width.
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

  // Shared, runtime-mutable block props read live at use-time (menu-open, tap);
  // the root mutates the one instance in place, so this view and any sibling
  // created later see the same current values. See DynamicBlockProps.
  var dynamicProps: DynamicBlockProps = DynamicBlockProps()

  // Wrap toggle labels (see AccessibilityLabels); the copy label lives on dynamicProps.
  var accessibilityLabels: AccessibilityLabels = AccessibilityLabels()
    set(value) {
      if (field == value) return
      field = value
      updateWrapButtonAppearance()
    }

  private var code: String = ""
  private var language: String? = null
  private var fenceChar: String = "`"
  private var appliedTextMaxWidth = Int.MAX_VALUE

  // True until the closing fence arrives: highlighting is deferred and copying
  // is disabled, while the header stays visible.
  var pending: Boolean = false
    set(value) {
      if (field == value) return
      field = value
      copyButton.isEnabled = !value
      if (value) resetCopyFeedback()
      // The reconciler can reuse an unchanged block without re-applying the
      // node, so re-derive here to pick up highlighting once the block closes.
      rebuildCodeText()
    }

  // Header wrap toggle next to copy; CodeBlockWrapState sets it from enableCodeBlockWrapToggle.
  var showsWrapButton: Boolean = false
    set(value) {
      if (field == value) return
      field = value
      wrapButton.visibility = if (value) View.VISIBLE else View.GONE
      requestLayout()
    }

  // Wraps long lines at the block width instead of scrolling horizontally. Only
  // CodeBlockWrapState writes it; the header toggle just asks through onWrapToggle.
  var wrapped: Boolean = false
    set(value) {
      if (field == value) return
      field = value
      updateWrapButtonAppearance()
      if (value) scrollView.scrollTo(0, 0)
      requestLayout()
    }

  // Fired when the header toggle is pressed; the host flips [wrapped] and re-measures.
  var onWrapToggle: ((CodeBlockContainerView) -> Unit)? = null

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

  private val copyIcon =
    CopyIconDrawable(
      secondaryColor(codeBlockStyle.color),
      ceil(codeBlockStyle.fontSize * HEADER_ICON_SCALE).toInt(),
    )

  // A main-looper handler rather than View.postDelayed, which defers work until attach.
  private val copyFeedbackHandler = Handler(Looper.getMainLooper())
  private val endCopyFeedback = Runnable { resetCopyFeedback() }

  internal val showsCopyFeedback: Boolean get() = copyIcon.showsCheckmark

  // contentDescription reads the shared label live so a runtime label change is
  // reflected for TalkBack without a push (mirrors the live block-menu reads).
  private val copyButton =
    object : AppCompatImageButton(context) {
      override fun getContentDescription(): CharSequence = dynamicProps.copyLabel
    }.apply {
      background = null
      scaleType = ImageView.ScaleType.CENTER
      setImageDrawable(copyIcon)
      setOnClickListener { copyCode() }
    }

  private val wrapIcon = WrapIconDrawable(codeBlockStyle.color, ceil(codeBlockStyle.fontSize * HEADER_ICON_SCALE).toInt())

  private val wrapButton =
    AppCompatImageButton(context).apply {
      background = null
      scaleType = ImageView.ScaleType.CENTER
      visibility = View.GONE
      setImageDrawable(wrapIcon)
      setOnClickListener { toggleWrap() }
    }

  private val dividerPaint =
    Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = dividerColor(codeBlockStyle.color)
      strokeWidth = context.resources.displayMetrics.density
    }

  private val tapDetector =
    GestureDetector(
      context,
      object : GestureDetector.SimpleOnGestureListener() {
        override fun onDown(e: MotionEvent): Boolean = true

        override fun onSingleTapUp(e: MotionEvent): Boolean {
          if (isPointInsideHeaderButton(e.x, e.y)) return false
          handleCodeBlockPress()
          return false
        }
      },
    )

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
    addView(wrapButton, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT))
    updateWrapButtonAppearance()
  }

  private fun updateWrapButtonAppearance() {
    // Full-strength tint marks the toggle as on; off matches the copy button.
    wrapIcon.setColor(if (wrapped) codeBlockStyle.color else secondaryColor(codeBlockStyle.color))
    wrapButton.contentDescription = if (wrapped) accessibilityLabels.codeBlockUnwrap else accessibilityLabels.codeBlockWrap
  }

  private fun toggleWrap() {
    onWrapToggle?.invoke(this)
  }

  fun applyCodeBlockNode(node: MarkdownASTNode) {
    val newCode = CodeBlockNode.extractCode(node)
    val newLanguage = CodeBlockNode.language(node)
    if (newCode != code || newLanguage != language) resetCopyFeedback()
    code = newCode
    fenceChar = CodeBlockNode.fenceChar(node)

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
    val paneWidth = (measuredWidth - borderW * 2).coerceAtLeast(0)
    // The scroll view measures its child unbounded; a max width makes the text wrap inside the pane.
    val textMaxWidth = if (wrapped) paneWidth.coerceAtLeast(1) else Int.MAX_VALUE
    if (textMaxWidth != appliedTextMaxWidth) {
      appliedTextMaxWidth = textMaxWidth
      textView.maxWidth = textMaxWidth
    }
    scrollView.measure(
      MeasureSpec.makeMeasureSpec(paneWidth, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED),
    )
    val buttonSpec = MeasureSpec.makeMeasureSpec(headerH, MeasureSpec.EXACTLY)
    copyButton.measure(buttonSpec, buttonSpec)
    wrapButton.measure(buttonSpec, buttonSpec)
    val headerButtonsWidth = if (showsWrapButton) headerH * 2 else headerH
    val labelMaxWidth = (measuredWidth - inset * 2 - headerButtonsWidth).coerceAtLeast(0)
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
    // The divider sits halfway into the code pane's top inset.
    val headerCenterY = (headerH + inset / 2f) / 2f
    val labelTop = (headerCenterY - languageView.measuredHeight / 2f).roundToInt()
    languageView.layout(
      inset,
      labelTop,
      inset + languageView.measuredWidth,
      labelTop + languageView.measuredHeight,
    )

    val iconWidth = copyButton.drawable?.intrinsicWidth ?: copyButton.measuredWidth
    val iconSlack = ((copyButton.measuredWidth - iconWidth) / 2).coerceAtLeast(0)
    val buttonLeft = (width - inset - copyButton.measuredWidth + iconSlack).coerceAtLeast(0)
    val buttonTop = (headerCenterY - copyButton.measuredHeight / 2f).roundToInt().coerceAtLeast(0)
    copyButton.layout(
      buttonLeft,
      buttonTop,
      buttonLeft + copyButton.measuredWidth,
      buttonTop + copyButton.measuredHeight,
    )
    val wrapLeft = (buttonLeft - wrapButton.measuredWidth).coerceAtLeast(0)
    wrapButton.layout(wrapLeft, buttonTop, wrapLeft + wrapButton.measuredWidth, buttonTop + wrapButton.measuredHeight)

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
    if (!dynamicProps.enableBlockContextMenu || pending) return false
    ContextMenuPopup.show(anchor, this) {
      item(ContextMenuPopup.Icon.COPY, dynamicProps.copyLabel) { copyCode() }
      item(ContextMenuPopup.Icon.DOCUMENT, dynamicProps.copyAsMarkdownLabel) { copyFencedMarkdown() }
    }
    return true
  }

  private fun copyCode() {
    if (pending || code.isEmpty()) return
    copyToClipboard(code)
    showCopyFeedback()
    dynamicProps.onCopyPress?.invoke(code, language ?: "")
  }

  private fun showCopyFeedback() {
    copyFeedbackHandler.removeCallbacks(endCopyFeedback)
    copyIcon.showsCheckmark = true
    copyFeedbackHandler.postDelayed(endCopyFeedback, COPY_FEEDBACK_DURATION_MS)
  }

  private fun resetCopyFeedback() {
    copyFeedbackHandler.removeCallbacks(endCopyFeedback)
    copyIcon.showsCheckmark = false
  }

  override fun onDetachedFromWindow() {
    super.onDetachedFromWindow()
    resetCopyFeedback()
  }

  private fun handleCodeBlockPress() {
    if (!dynamicProps.enableCodeBlockPress || pending) return
    dynamicProps.onCodeBlockPress?.invoke(code, language ?: "")
  }

  override fun dispatchTouchEvent(ev: MotionEvent): Boolean {
    tapDetector.onTouchEvent(ev)
    return super.dispatchTouchEvent(ev)
  }

  private fun isPointInsideHeaderButton(
    x: Float,
    y: Float,
  ): Boolean = isPointInside(copyButton, x, y) || (wrapButton.visibility == View.VISIBLE && isPointInside(wrapButton, x, y))

  private fun isPointInside(
    view: View,
    x: Float,
    y: Float,
  ): Boolean = x >= view.left && x < view.right && y >= view.top && y < view.bottom

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
    private val checkmarkGlyph = CheckmarkGlyph()

    var showsCheckmark = false
      set(value) {
        if (field == value) return
        field = value
        invalidateSelf()
      }

    override fun draw(canvas: Canvas) {
      if (showsCheckmark) {
        checkmarkGlyph.draw(canvas, bounds.width().toFloat(), paint)
      } else {
        glyph.draw(canvas, bounds.width().toFloat(), paint)
      }
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

  // Material "wrap_text" glyph, stroked like the copy glyph at the same size.
  private class WrapIconDrawable(
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
    private val glyph = WrapGlyph()

    fun setColor(color: Int) {
      paint.color = color
      invalidateSelf()
    }

    override fun draw(canvas: Canvas) {
      val saved = canvas.save()
      canvas.translate(bounds.left.toFloat(), bounds.top.toFloat())
      glyph.draw(canvas, bounds.width().toFloat(), paint)
      canvas.restoreToCount(saved)
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
    internal const val COPY_FEEDBACK_DURATION_MS = 1500L

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

    // Unwrapped lines never wrap (the code pane scrolls horizontally), so the
    // layout is built at the text's desired width and the result is independent
    // of the available width. A wrapped block lays out at the pane's text width
    // instead, the same width the view caps its text view at.
    fun measureCodeBlockNodeHeight(
      node: MarkdownASTNode,
      config: StyleConfig,
      context: Context,
      width: Float,
      wrapped: Boolean = false,
    ): Float {
      val style = config.codeBlockStyle
      val inset = contentInset(style)
      val headerH = headerHeight(style)
      val text = buildCodeText(CodeBlockNode.extractCode(node), style)
      if (text.isEmpty()) return headerH + inset * 2f
      val paint = createCodePaint(style, context)
      val layoutWidth =
        if (wrapped) {
          val borderW = borderPx(style)
          val horizontalPad = (inset - borderW).coerceAtLeast(0)
          // Mirrors onMeasure: the text view is capped at the pane width (at least 1px), padding included.
          (ceil(width).toInt() - borderW * 2).coerceAtLeast(1) - horizontalPad * 2
        } else {
          ceil(Layout.getDesiredWidth(text, paint)).toInt()
        }
      val contentWidth = layoutWidth.coerceAtLeast(1)
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
