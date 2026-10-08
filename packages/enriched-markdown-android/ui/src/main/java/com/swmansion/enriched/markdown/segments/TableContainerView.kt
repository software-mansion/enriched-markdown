package com.swmansion.enriched.markdown.segments

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.text.Layout
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import androidx.core.view.ViewCompat
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.plugin.EnrichedMarkdownPlugins
import com.swmansion.enriched.markdown.plugin.PluginEventSink
import com.swmansion.enriched.markdown.plugin.PluginSnapshot
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.spans.registerCodeBackgrounds
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.TableAlignment
import com.swmansion.enriched.markdown.styles.TableStyle
import com.swmansion.enriched.markdown.utils.common.layout.isLayoutRTL
import com.swmansion.enriched.markdown.utils.text.conversion.HTMLGenerator
import com.swmansion.enriched.markdown.utils.text.view.LinkLongPressMovementMethod
import com.swmansion.enriched.markdown.utils.text.view.SelectionMenuConfig
import com.swmansion.enriched.markdown.utils.text.view.SelectionMenuConfigurable
import com.swmansion.enriched.markdown.views.ContextMenuPopup
import kotlin.math.ceil
import kotlin.math.max

class TableContainerView(
  context: Context,
  private val styleConfig: StyleConfig,
) : FrameLayout(context),
  BlockSegmentView,
  SelectionMenuConfigurable {
  internal val tableStyle: TableStyle = styleConfig.tableStyle

  override val segmentMarginTop: Int get() = tableStyle.marginTop.toInt()
  override val segmentMarginBottom: Int get() = tableStyle.marginBottom.toInt()
  private val density = resources.displayMetrics.density
  private val isRtl = resources.isLayoutRTL()

  var onLinkPress: ((String) -> Unit)? = null
  var onLinkLongPress: ((String) -> Unit)? = null
  override var selectionMenuConfig: SelectionMenuConfig = SelectionMenuConfig()

  private val scrollView =
    HorizontalScrollView(context).apply {
      isHorizontalScrollBarEnabled = true
      overScrollMode = View.OVER_SCROLL_NEVER
      importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
      addView(
        GridContainerView(context).apply {
          importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        },
      )
    }
  private val gridContainer get() = scrollView.getChildAt(0) as GridContainerView

  private var table: RenderedTable? = null
  private val rows: List<List<TableCellData>> get() = table?.rows.orEmpty()
  private var totalTableWidth = 0f
  private var totalTableHeight = 0f

  init {
    importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
    addView(scrollView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
  }

  /** Main thread: builds the grid for a table the render thread already rendered and measured. */
  fun applyRenderedTable(renderedTable: RenderedTable) {
    table?.links?.view = null
    table = renderedTable
    renderedTable.links.view = this
    totalTableWidth = renderedTable.columnWidths.sum() + tableStyle.borderWidth
    totalTableHeight = renderedTable.rowHeights.sum() + tableStyle.borderWidth

    renderGrid(renderedTable)
  }

  /** Renders [tableNode] on the calling thread, then applies it. Core renders on the render thread instead. */
  fun applyTableNode(
    tableNode: MarkdownASTNode,
    imageRequestHeaders: Map<String, String> = emptyMap(),
    plugins: PluginSnapshot = EnrichedMarkdownPlugins.snapshot,
    onPluginEvent: PluginEventSink? = null,
  ) {
    applyRenderedTable(RenderedTable.render(tableNode, styleConfig, context, imageRequestHeaders, plugins, onPluginEvent))
  }

  private fun renderGrid(table: RenderedTable) {
    val rowHeights = table.rowHeights
    val columnWidths = table.columnWidths
    gridContainer.removeAllViews()
    gridContainer.configure(tableStyle)

    var yOffset = 0f
    var bodyRowIndex = 0

    table.rows.forEachIndexed { rowIndex, row ->
      val rowHeight = rowHeights[rowIndex]
      val isHeaderRow = row.firstOrNull()?.isHeader == true
      val rowBg =
        when {
          isHeaderRow -> tableStyle.headerBackgroundColor
          bodyRowIndex % 2 == 0 -> tableStyle.rowEvenBackgroundColor
          else -> tableStyle.rowOddBackgroundColor
        }

      var xOffset = if (isRtl) totalTableWidth - tableStyle.borderWidth else 0f
      for (col in 0 until table.columnCount) {
        val columnWidth = columnWidths[col]

        val cellX =
          if (isRtl) {
            xOffset -= columnWidth
            xOffset
          } else {
            xOffset
          }

        val cellBg =
          CellBackgroundView(context).apply {
            configure(rowBg, tableStyle.borderColor, tableStyle.borderWidth)
            setOnLongClickListener { view -> showContextMenu(view) }
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
          }

        gridContainer.addView(
          cellBg,
          LayoutParams(ceil(columnWidth + tableStyle.borderWidth).toInt(), ceil(rowHeight + tableStyle.borderWidth).toInt()).apply {
            leftMargin = ceil(cellX).toInt()
            topMargin = ceil(yOffset).toInt()
          },
        )

        if (col < row.size) addTextToCell(cellBg, row[col], columnWidth, rowHeight)
        if (!isRtl) xOffset += columnWidth
      }

      addRowAccessibilityOverlay(row, rowIndex, isHeaderRow, yOffset, rowHeight)

      if (!isHeaderRow) bodyRowIndex++
      yOffset += rowHeight
    }
    gridContainer.layoutParams = LayoutParams(ceil(totalTableWidth).toInt(), ceil(totalTableHeight).toInt())
  }

  private fun addRowAccessibilityOverlay(
    row: List<TableCellData>,
    rowIndex: Int,
    isHeaderRow: Boolean,
    yOffset: Float,
    rowHeight: Float,
  ) {
    val joinedContent = row.joinToString(", ") { it.plainText }
    val description = "Row ${rowIndex + 1}: $joinedContent"

    val overlay =
      View(context).apply {
        isClickable = false
        isLongClickable = false
        isFocusable = true
        isScreenReaderFocusable = true
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
        contentDescription = description
        if (isHeaderRow) ViewCompat.setAccessibilityHeading(this, true)
      }
    // Below every cell, but after the previous rows' overlays so traversal follows document order.
    gridContainer.addView(
      overlay,
      rowIndex,
      LayoutParams(
        ceil(totalTableWidth).toInt(),
        ceil(rowHeight + tableStyle.borderWidth).toInt(),
      ).apply {
        leftMargin = 0
        topMargin = ceil(yOffset).toInt()
      },
    )
  }

  private fun addTextToCell(
    container: CellBackgroundView,
    data: TableCellData,
    width: Float,
    height: Float,
  ) {
    val cellTextView =
      CellTextView(context).apply {
        text = data.attributedText
        textSize = tableStyle.fontSize / resources.displayMetrics.scaledDensity
        typeface = if (data.isHeader) styleConfig.tableHeaderTypeface else styleConfig.tableTypeface
        setTextColor(if (data.isHeader) tableStyle.headerTextColor else tableStyle.color)
        gravity =
          when (data.alignment) {
            Layout.Alignment.ALIGN_CENTER -> Gravity.CENTER_HORIZONTAL
            Layout.Alignment.ALIGN_OPPOSITE -> Gravity.END
            else -> Gravity.START
          }
        setOnLongClickListener { view -> showContextMenu(view) }
      }
    val horizontalPadding = tableStyle.cellPaddingHorizontal
    val verticalPadding = tableStyle.cellPaddingVertical
    container.addView(
      cellTextView,
      LayoutParams(
        (width - horizontalPadding * 2).toInt().coerceAtLeast(1),
        (height - verticalPadding * 2).toInt().coerceAtLeast(1),
      ).apply {
        leftMargin = ceil(horizontalPadding).toInt()
        topMargin = ceil(verticalPadding).toInt()
      },
    )
    data.attributedText
      .getSpans(0, data.attributedText.length, ImageSpan::class.java)
      .forEach { it.registerTextView(cellTextView) }
    cellTextView.registerCodeBackgrounds(data.attributedText)
  }

  override fun onMeasure(
    widthSpec: Int,
    heightSpec: Int,
  ) {
    // UNSPECIFIED carries size 0, so fall back to the table's own width there.
    val measuredWidth = resolveSize(ceil(totalTableWidth).toInt(), widthSpec)
    val measuredHeight = ceil(totalTableHeight).toInt()
    scrollView.measure(
      MeasureSpec.makeMeasureSpec(measuredWidth, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(measuredHeight, MeasureSpec.EXACTLY),
    )
    setMeasuredDimension(measuredWidth, measuredHeight)
  }

  override fun onLayout(
    changed: Boolean,
    left: Int,
    top: Int,
    right: Int,
    bottom: Int,
  ) {
    val viewWidth = right - left
    val overhang = max(ceil(tableStyle.horizontalOverflow.toDouble()).toInt(), 0)
    val contentWidth = viewWidth - overhang * 2
    val tableOverflows = totalTableWidth > contentWidth

    scrollView.setPadding(overhang, 0, overhang, 0)
    scrollView.clipToPadding = !tableOverflows
    scrollView.isHorizontalScrollBarEnabled = tableOverflows

    scrollView.layout(0, 0, viewWidth, bottom - top)

    gridContainer.translationX =
      if (!tableOverflows) {
        val freeSpace = max(contentWidth - totalTableWidth, 0f)
        val desiredLeft =
          overhang +
            when (tableStyle.align) {
              TableAlignment.CENTER -> freeSpace / 2f
              TableAlignment.RIGHT -> freeSpace
              TableAlignment.LEFT -> 0f
              TableAlignment.AUTO -> if (isRtl) freeSpace else 0f
              TableAlignment.END -> if (isRtl) 0f else freeSpace
            }
        desiredLeft - gridContainer.left
      } else {
        0f
      }

    if (isRtl) {
      val effectiveWidth = if (tableOverflows) contentWidth.toFloat() else viewWidth.toFloat()
      if (totalTableWidth > effectiveWidth) {
        scrollView.scrollTo((totalTableWidth - effectiveWidth).toInt(), 0)
      }
    }
  }

  private fun showContextMenu(anchor: View): Boolean {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    ContextMenuPopup.show(anchor, this) {
      item(ContextMenuPopup.Icon.COPY, context.getString(android.R.string.copy)) {
        val plainText = rows.joinToString("\n") { row -> row.joinToString("\t") { it.plainText } }
        if (plainText.isNotEmpty()) {
          val displayMetrics = context.resources.displayMetrics
          val tableRows =
            rows.map { row ->
              row.map { cell -> Triple(cell.attributedText as CharSequence, cell.isHeader, cell.sourceAlignment) }
            }
          val html = HTMLGenerator.generateTableHTML(tableRows, styleConfig, displayMetrics.scaledDensity, displayMetrics.density)
          clipboard.setPrimaryClip(ClipData.newHtmlText("Table", plainText, html))
        }
      }
      if (selectionMenuConfig.copyAsMarkdown) {
        item(
          ContextMenuPopup.Icon.DOCUMENT,
          selectionMenuConfig.resolvedCopyAsMarkdownLabel,
        ) {
          val tableMarkdown = table?.markdown.orEmpty()
          if (tableMarkdown.isNotEmpty()) clipboard.setPrimaryClip(ClipData.newPlainText("Table", tableMarkdown))
        }
      }
    }
    return true
  }

  private class GridContainerView(
    context: Context,
  ) : FrameLayout(context) {
    private var radius = 0f
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val path = Path()
    private val rect = RectF()

    init {
      layoutDirection = View.LAYOUT_DIRECTION_LTR
    }

    fun configure(style: TableStyle) {
      radius = style.borderRadius
      paint.color = style.borderColor
      paint.strokeWidth = style.borderWidth
    }

    override fun dispatchDraw(canvas: Canvas) {
      rect.set(0f, 0f, width.toFloat(), height.toFloat())
      if (radius > 0f) {
        path.apply {
          reset()
          addRoundRect(rect, radius, radius, Path.Direction.CW)
        }
        canvas.save()
        canvas.clipPath(path)
        super.dispatchDraw(canvas)
        canvas.restore()
        val halfStroke = paint.strokeWidth / 2
        rect.inset(halfStroke, halfStroke)
        canvas.drawRoundRect(rect, radius, radius, paint)
      } else {
        super.dispatchDraw(canvas)
        canvas.drawRect(rect, paint)
      }
    }
  }

  private class CellBackgroundView(
    context: Context,
  ) : FrameLayout(context) {
    private val backgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }

    fun configure(
      backgroundColor: Int,
      borderColor: Int,
      borderWidth: Float,
    ) {
      backgroundPaint.color = backgroundColor
      borderPaint.color = borderColor
      borderPaint.strokeWidth = borderWidth
    }

    override fun dispatchDraw(canvas: Canvas) {
      canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), backgroundPaint)
      if (borderPaint.strokeWidth > 0f) {
        val halfStroke = borderPaint.strokeWidth / 2
        canvas.drawRect(halfStroke, halfStroke, width.toFloat() - halfStroke, height.toFloat() - halfStroke, borderPaint)
      }
      super.dispatchDraw(canvas)
    }
  }

  private class CellTextView(
    context: Context,
  ) : androidx.appcompat.widget.AppCompatTextView(context) {
    init {
      setPadding(0, 0, 0, 0)
      includeFontPadding = false
      movementMethod = LinkLongPressMovementMethod.createInstance()
      layoutDirection = View.LAYOUT_DIRECTION_LOCALE
      textDirection = View.TEXT_DIRECTION_LOCALE
      importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
    }
  }
}
