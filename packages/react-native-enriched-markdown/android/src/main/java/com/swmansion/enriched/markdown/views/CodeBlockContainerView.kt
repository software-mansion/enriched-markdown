package com.swmansion.enriched.markdown.views

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.text.Layout
import android.text.SpannableString
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.util.TypedValue
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import androidx.appcompat.widget.AppCompatImageButton
import androidx.appcompat.widget.AppCompatTextView
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
 * The block consists of a header bar (language display name on the left, a
 * copy-code button on the right) and the code text below it, all inside the
 * code block background, border, and padding. Long lines wrap, matching the
 * previous span-based rendering (horizontal scrolling can be added later as a
 * style option). Syntax coloring is delegated to the shared C++ highlighting
 * seam through the CodeBlockHighlighter adapter; when the highlighting module
 * is compiled out the code is drawn uncolored.
 *
 * Measurement parity: measureCodeBlockNodeHeight builds the same styled text
 * and paint as the view and derives the header height from the same label
 * font metrics, so the height reported to Yoga at shadow-node measure time
 * matches the height the view lays out with. The text view disables font
 * padding and uses the simple break strategy so its internal layout matches
 * the StaticLayout used for measurement.
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
    set(value) {
      field = value
      copyButton.contentDescription = value
    }
  var copyAsMarkdownLabel: String = ""

  private var code: String = ""
  private var language: String? = null
  private var fenceChar: String = "`"

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
      val inset = contentInset(codeBlockStyle)
      setPadding(inset, inset, inset, inset)
      setOnLongClickListener { view ->
        showContextMenu(view)
        true
      }
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
        CopyIconDrawable(secondaryColor(codeBlockStyle.color), ceil(codeBlockStyle.fontSize).toInt()),
      )
      setOnClickListener {
        if (code.isNotEmpty()) {
          val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
          clipboard.setPrimaryClip(ClipData.newPlainText("Code", code))
        }
      }
    }

  init {
    background =
      GradientDrawable().apply {
        setColor(codeBlockStyle.backgroundColor)
        cornerRadius = codeBlockStyle.borderRadius
        if (codeBlockStyle.borderWidth > 0f) {
          setStroke(ceil(codeBlockStyle.borderWidth).toInt(), codeBlockStyle.borderColor)
        }
      }
    isLongClickable = true
    setOnLongClickListener { view ->
      showContextMenu(view)
      true
    }
    addView(textView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
    addView(languageView, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT))
    addView(copyButton, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT))
  }

  fun applyCodeBlockNode(node: MarkdownASTNode) {
    code = extractCode(node)
    language = node.getAttribute("language")?.takeIf { it.isNotEmpty() }
    fenceChar = node.getAttribute("fenceChar")?.takeIf { it.isNotEmpty() } ?: "`"

    languageView.text = displayLanguageName(language)

    val plainCode = buildCodeText(code, codeBlockStyle)
    textView.text = CodeBlockHighlighter.highlight(plainCode, code, language) ?: plainCode
  }

  override fun onMeasure(
    widthSpec: Int,
    heightSpec: Int,
  ) {
    val measuredWidth = MeasureSpec.getSize(widthSpec)
    val headerH = headerHeight(codeBlockStyle)
    val inset = contentInset(codeBlockStyle)
    textView.measure(
      MeasureSpec.makeMeasureSpec(measuredWidth, MeasureSpec.EXACTLY),
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
    setMeasuredDimension(measuredWidth, headerH + textView.measuredHeight)
  }

  override fun onLayout(
    changed: Boolean,
    left: Int,
    top: Int,
    right: Int,
    bottom: Int,
  ) {
    val width = right - left
    val headerH = headerHeight(codeBlockStyle)
    val inset = contentInset(codeBlockStyle)

    val labelTop = (headerH - languageView.measuredHeight) / 2
    languageView.layout(
      inset,
      labelTop,
      inset + languageView.measuredWidth,
      labelTop + languageView.measuredHeight,
    )

    val iconWidth = copyButton.drawable?.intrinsicWidth ?: copyButton.measuredWidth
    val iconSlack = ((copyButton.measuredWidth - iconWidth) / 2).coerceAtLeast(0)
    val buttonLeft = (width - inset - copyButton.measuredWidth + iconSlack).coerceAtLeast(0)
    copyButton.layout(buttonLeft, 0, buttonLeft + copyButton.measuredWidth, copyButton.measuredHeight)

    textView.layout(0, headerH, width, bottom - top)
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

  private class CopyIconDrawable(
    color: Int,
    private val size: Int,
  ) : Drawable() {
    private val paint =
      Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = size / 12f
        strokeJoin = Paint.Join.ROUND
        strokeCap = Paint.Cap.ROUND
        this.color = color
      }

    override fun draw(canvas: Canvas) {
      val u = bounds.width() / 24f
      canvas.drawRoundRect(RectF(8 * u, 2 * u, 22 * u, 16 * u), 2 * u, 2 * u, paint)
      canvas.drawRoundRect(RectF(2 * u, 8 * u, 16 * u, 22 * u), 2 * u, 2 * u, paint)
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

    private val headerTypeface: Typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)

    private val languageNames =
      mapOf(
        "bash" to "Bash",
        "c" to "C",
        "cc" to "C++",
        "cpp" to "C++",
        "cs" to "C#",
        "csharp" to "C#",
        "css" to "CSS",
        "cxx" to "C++",
        "dockerfile" to "Dockerfile",
        "go" to "Go",
        "golang" to "Go",
        "graphql" to "GraphQL",
        "html" to "HTML",
        "java" to "Java",
        "javascript" to "JavaScript",
        "js" to "JavaScript",
        "json" to "JSON",
        "jsx" to "JSX",
        "kotlin" to "Kotlin",
        "kt" to "Kotlin",
        "markdown" to "Markdown",
        "md" to "Markdown",
        "objc" to "Objective-C",
        "objectivec" to "Objective-C",
        "php" to "PHP",
        "py" to "Python",
        "python" to "Python",
        "rb" to "Ruby",
        "ruby" to "Ruby",
        "rs" to "Rust",
        "rust" to "Rust",
        "scss" to "SCSS",
        "sh" to "Shell",
        "shell" to "Shell",
        "sql" to "SQL",
        "swift" to "Swift",
        "toml" to "TOML",
        "ts" to "TypeScript",
        "tsx" to "TSX",
        "typescript" to "TypeScript",
        "xml" to "XML",
        "yaml" to "YAML",
        "yml" to "YAML",
        "zsh" to "Zsh",
      )

    private fun displayLanguageName(language: String?): String {
      val lang = language?.lowercase() ?: return ""
      return languageNames[lang] ?: lang.replaceFirstChar { it.uppercase() }
    }

    private fun secondaryColor(color: Int): Int = (color and 0x00FFFFFF) or (0x99 shl 24)

    private fun contentInset(style: CodeBlockStyle): Int = ceil(style.padding + style.borderWidth).toInt()

    private fun headerHeight(style: CodeBlockStyle): Int {
      val paint =
        TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
          textSize = style.fontSize * HEADER_LABEL_SCALE
          typeface = headerTypeface
        }
      val metrics = paint.fontMetrics
      return ceil(metrics.descent - metrics.ascent).toInt() + ceil(style.padding).toInt() * 2
    }

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
      val headerH = headerHeight(style)
      val text = buildCodeText(extractCode(node), style)
      if (text.isEmpty()) return headerH + inset * 2f
      val contentWidth = (ceil(width).toInt() - inset * 2).coerceAtLeast(1)
      val layout =
        StaticLayout.Builder
          .obtain(text, 0, text.length, createCodePaint(style, context), contentWidth)
          .setIncludePad(false)
          .setLineSpacing(0f, 1f)
          .setBreakStrategy(Layout.BREAK_STRATEGY_SIMPLE)
          .setHyphenationFrequency(Layout.HYPHENATION_FREQUENCY_NONE)
          .build()
      return layout.height.toFloat() + inset * 2 + headerH
    }
  }
}
