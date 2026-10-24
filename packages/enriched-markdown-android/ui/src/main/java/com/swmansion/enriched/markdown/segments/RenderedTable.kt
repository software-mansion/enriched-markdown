package com.swmansion.enriched.markdown.segments

import android.content.Context
import android.graphics.Paint
import android.graphics.Typeface
import android.text.Layout
import android.text.Spannable
import android.text.StaticLayout
import android.text.TextPaint
import android.text.style.AlignmentSpan
import android.text.style.MetricAffectingSpan
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.plugin.PluginEventSink
import com.swmansion.enriched.markdown.plugin.PluginSnapshot
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.common.layout.isLayoutRTL
import com.swmansion.enriched.markdown.utils.common.serialization.MarkdownASTSerializer
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

/**
 * A table with its cells rendered and measured, made on the render thread like a text segment's
 * spannable, so the view is left to build the grid. Rendering a cell runs every node renderer in
 * it, a plugin's included, and those must not run on the main thread.
 */
class RenderedTable internal constructor(
  internal val rows: List<List<TableCellData>>,
  internal val columnCount: Int,
  internal val columnWidths: List<Float>,
  internal val rowHeights: List<Float>,
  /** AST-based, not row-based: [TableCellData.alignment] is mirrored in RTL, so rows would emit the wrong marker. */
  internal val markdown: String,
  internal val links: TableLinkRelay,
) {
  companion object {
    /** Render thread. */
    fun render(
      tableNode: MarkdownASTNode,
      style: StyleConfig,
      context: Context,
      imageRequestHeaders: Map<String, String>,
      plugins: PluginSnapshot,
      onPluginEvent: PluginEventSink?,
    ): RenderedTable {
      val isRtl = context.resources.isLayoutRTL()
      val links = TableLinkRelay()
      val rows =
        tableNode.children.flatMap { section ->
          val isSectionHead = section.type == NodeType.TableHead
          section.children.filter { it.type == NodeType.TableRow }.map { row ->
            row.children.map { cell ->
              val isHeader = isSectionHead || cell.type == NodeType.TableHeaderCell
              val sourceAlignment = cell.getAttribute("align")
              val align = textAlignmentFromString(sourceAlignment, isRtl)
              TableCellData(
                attributedText = renderCellNode(cell, isHeader, align, style, context, imageRequestHeaders, plugins, onPluginEvent, links),
                plainText = extractPlainText(cell),
                isHeader = isHeader,
                alignment = align,
                sourceAlignment = sourceAlignment,
              )
            }
          }
        }

      val (columnWidths, rowHeights) = computeTableDimensions(rows.map { row -> row.map { it.attributedText } }, style, context)
      return RenderedTable(
        rows = rows,
        columnCount = rows.maxOfOrNull { it.size } ?: 0,
        columnWidths = columnWidths,
        rowHeights = rowHeights,
        markdown = MarkdownASTSerializer.serializeTable(tableNode),
        links = links,
      )
    }

    private fun renderCellNode(
      node: MarkdownASTNode,
      isHeader: Boolean,
      alignment: Layout.Alignment,
      style: StyleConfig,
      context: Context,
      imageRequestHeaders: Map<String, String>,
      plugins: PluginSnapshot,
      onPluginEvent: PluginEventSink?,
      links: TableLinkRelay,
    ): Spannable {
      val paragraph = MarkdownASTNode(NodeType.Paragraph, children = node.children)
      val cellStyle = style.withParagraphStyle(style.tableCellParagraphStyle(isHeader))
      return Renderer()
        .apply { configure(cellStyle, context, imageRequestHeaders, onPluginEvent, plugins) }
        .renderContent(listOf(paragraph), links::onLinkPress, links::onLinkLongPress)
        .apply {
          if (isNotEmpty()) {
            if (isHeader) setSpan(HeaderTypefaceSpan(style.tableHeaderTypeface ?: Typeface.DEFAULT_BOLD), 0, length, 33)
            if (alignment != Layout.Alignment.ALIGN_NORMAL) setSpan(AlignmentSpan.Standard(alignment), 0, length, 33)
          }
        }
    }

    private fun extractPlainText(node: MarkdownASTNode): String =
      when (node.type) {
        // A space rather than a newline: plain-text copy is newline-separated per row.
        NodeType.LineBreak, NodeType.SoftBreak -> " "

        else -> node.content + node.children.joinToString("") { extractPlainText(it) }
      }

    private fun textAlignmentFromString(
      align: String?,
      isRtl: Boolean,
    ): Layout.Alignment =
      when (align) {
        "center" -> Layout.Alignment.ALIGN_CENTER
        "right" -> if (isRtl) Layout.Alignment.ALIGN_NORMAL else Layout.Alignment.ALIGN_OPPOSITE
        "left" -> if (isRtl) Layout.Alignment.ALIGN_OPPOSITE else Layout.Alignment.ALIGN_NORMAL
        else -> Layout.Alignment.ALIGN_NORMAL
      }

    private fun computeTableDimensions(
      texts: List<List<CharSequence>>,
      config: StyleConfig,
      context: Context,
    ): Pair<List<Float>, List<Float>> {
      val style = config.tableStyle
      val density = context.resources.displayMetrics.density
      val (minColumnWidth, maxColumnWidth) = 60f * density to 300f * density
      val (horizontalPadding, verticalPadding) = style.cellPaddingHorizontal * 2 to style.cellPaddingVertical * 2
      val paint =
        TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
          textSize = style.fontSize
          typeface = config.tableTypeface
        }

      val layouts =
        texts.map { row ->
          row.map { cellText -> buildCellLayout(cellText, paint, maxColumnWidth.toInt()) }
        }

      val columnWidths = FloatArray(texts.maxOfOrNull { it.size } ?: 0)
      layouts.forEach { row ->
        row.forEachIndexed { colIndex, layout ->
          val textWidth = layout.widestLine()
          columnWidths[colIndex] =
            max(columnWidths[colIndex], min(max(ceil(textWidth) + horizontalPadding, minColumnWidth), maxColumnWidth + horizontalPadding))
        }
      }

      val rowHeights =
        layouts.map { row ->
          row
            .mapIndexed { colIndex, layout ->
              val contentWidth = (columnWidths[colIndex] - horizontalPadding).toInt().coerceAtLeast(1)
              // Laid out at the widest a column gets, a cell that did not wrap breaks the same in a column it fits.
              val reusable = contentWidth >= layout.width || (!layout.wrapsAnyLine() && layout.widestLine() <= contentWidth)
              val fitted = if (reusable) layout else buildCellLayout(layout.text, paint, contentWidth)
              ceil(fitted.height.toFloat()) + verticalPadding
            }.maxOfOrNull { it } ?: 0f
        }
      return columnWidths.toList() to rowHeights
    }

    private fun buildCellLayout(
      text: CharSequence,
      paint: TextPaint,
      width: Int,
    ): StaticLayout =
      StaticLayout.Builder
        .obtain(text, 0, text.length, paint, width)
        .setIncludePad(false)
        .build()

    private fun Layout.widestLine(): Float = (0 until lineCount).maxOfOrNull { line -> getLineWidth(line) } ?: 0f

    /** Whether a line ends where the text itself has no line break. */
    private fun Layout.wrapsAnyLine(): Boolean = (0 until lineCount - 1).any { line -> text[getLineEnd(line) - 1] != '\n' }
  }

  private class HeaderTypefaceSpan(
    private val typeface: Typeface,
  ) : MetricAffectingSpan() {
    override fun updateDrawState(paint: TextPaint) {
      paint.typeface = typeface
    }

    override fun updateMeasureState(paint: TextPaint) {
      paint.typeface = typeface
    }
  }
}

/**
 * Where a table's links report. Its cells, links included, are rendered before there is a view to
 * capture, so the view that shows them registers here, and a tap reaches whichever callbacks that
 * view holds at the time - later `setOnLinkPress*` calls included.
 */
internal class TableLinkRelay {
  var view: TableContainerView? = null

  fun onLinkPress(url: String) {
    view?.onLinkPress?.invoke(url)
  }

  fun onLinkLongPress(url: String) {
    view?.onLinkLongPress?.invoke(url)
  }
}

internal data class TableCellData(
  val attributedText: Spannable,
  val plainText: String,
  val isHeader: Boolean,
  val alignment: Layout.Alignment,
  /** The GFM `align` attribute; [alignment] is mirrored in RTL, so HTML export needs the original. */
  val sourceAlignment: String?,
)
