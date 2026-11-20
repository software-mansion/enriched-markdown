package com.swmansion.enriched.markdown.highlight

import android.graphics.RectF
import android.graphics.drawable.GradientDrawable
import android.view.View
import com.facebook.react.uimanager.PixelUtil
import java.util.WeakHashMap
import kotlin.math.abs

/** A text view whose highlights a [TextHighlightCoordinator] sets. */
interface TextHighlightHost {
  val highlightPainter: TextHighlightPainter
}

/** A block that draws its own text, such as a code block or a table. */
interface RenderedTextProvider {
  /** The text the block shows, for the `highlights` offsets to index into. */
  val renderedText: String

  /** "code" or "table". */
  val renderedTextKind: String

  /** Corner radius of the tint drawn over the block, in pixels. */
  val highlightCornerRadius: Float
}

/** The part of the rendered text that one block shows. */
data class RenderedTextBlock(
  val start: Int,
  val end: Int,
  val kind: String,
)

/** Where one highlight shows, in the host's coordinates, in dp. */
data class HighlightRect(
  val index: Int,
  val x: Float,
  val y: Float,
  val width: Float,
  val height: Float,
) {
  fun isCloseTo(other: HighlightRect): Boolean =
    index == other.index &&
      abs(x - other.x) < 0.5f &&
      abs(y - other.y) < 0.5f &&
      abs(width - other.width) < 0.5f &&
      abs(height - other.height) < 0.5f
}

/**
 * Maps the `highlights` prop onto a markdown view's blocks. The rendered text is
 * the blocks' text in document order, joined with "\n". A text view draws its
 * part of each highlight behind its glyphs; a block that draws its own text gets
 * a tint over the whole block.
 */
class TextHighlightCoordinator(
  private val host: View,
  private val onLayout: (List<HighlightRect>) -> Unit,
) {
  var highlights: List<TextHighlight> = emptyList()
    set(value) {
      if (field == value) return
      field = value
      applyHighlights()
      reportLayout()
    }

  var renderedText: String = ""
    private set
  var renderedBlocks: List<RenderedTextBlock> = emptyList()
    private set

  private var blockViews: List<View> = emptyList()
  private val overlays = WeakHashMap<View, List<GradientDrawable>>()
  private val overlayHighlights = WeakHashMap<View, List<TextHighlight>>()
  private var reportedRects: List<HighlightRect> = emptyList()

  /** Takes the blocks after a render. Returns whether the rendered text or its blocks changed. */
  fun setBlockViews(views: List<View>): Boolean {
    val kept = ArrayList<View>(views.size)
    val blocks = ArrayList<RenderedTextBlock>(views.size)
    val text = StringBuilder()
    for (view in views) {
      val (blockText, kind) =
        when (view) {
          is TextHighlightHost -> (view as? android.widget.TextView)?.text?.toString().orEmpty() to "text"
          is RenderedTextProvider -> view.renderedText to view.renderedTextKind
          else -> continue
        }
      if (kept.isNotEmpty()) text.append(BLOCK_SEPARATOR)
      val start = text.length
      text.append(blockText)
      kept += view
      blocks += RenderedTextBlock(start, text.length, kind)
    }

    // Views that left the document drop what they drew.
    blockViews.filter { old -> kept.none { it === old } }.forEach { applyHighlights(emptyList(), it) }

    val newText = text.toString()
    val changed = newText != renderedText || blocks != renderedBlocks
    blockViews = kept
    renderedText = newText
    renderedBlocks = blocks
    applyHighlights()
    return changed
  }

  private fun localHighlights(blockIndex: Int): List<TextHighlight> {
    val block = renderedBlocks[blockIndex]
    return highlights.mapNotNull { it.inBlock(block.start, block.end) }
  }

  private fun applyHighlights() {
    blockViews.forEachIndexed { index, view -> applyHighlights(localHighlights(index), view) }
  }

  private fun applyHighlights(
    local: List<TextHighlight>,
    view: View,
  ) {
    if (view is TextHighlightHost) {
      view.highlightPainter.highlights = local
      return
    }
    if (overlayHighlights[view].orEmpty() == local) return
    overlays.remove(view)?.forEach { view.overlay.remove(it) }
    val radius = (view as? RenderedTextProvider)?.highlightCornerRadius ?: 0f
    val drawables =
      local.map { highlight ->
        GradientDrawable().apply {
          setColor(highlight.color)
          cornerRadius = radius
          setBounds(0, 0, view.width, view.height)
        }
      }
    drawables.forEach { view.overlay.add(it) }
    overlays[view] = drawables
    overlayHighlights[view] = local
  }

  /** Reports the highlights' boxes again if they moved. Call after the host lays out. */
  fun reportLayout() {
    // A block that grew keeps its tint covering it.
    overlays.forEach { (view, drawables) -> drawables.forEach { it.setBounds(0, 0, view.width, view.height) } }

    val unions = arrayOfNulls<RectF>(highlights.size)
    blockViews.forEachIndexed { blockIndex, view ->
      val block = renderedBlocks[blockIndex]
      val (offsetX, offsetY) = offsetInHost(view) ?: return@forEachIndexed
      highlights.forEachIndexed { index, highlight ->
        val local = highlight.inBlock(block.start, block.end) ?: return@forEachIndexed
        val rect =
          if (view is TextHighlightHost) {
            view.highlightPainter.bounds(local) ?: return@forEachIndexed
          } else {
            RectF(0f, 0f, view.width.toFloat(), view.height.toFloat())
          }
        rect.offset(offsetX, offsetY)
        val current = unions[index]
        if (current == null) unions[index] = rect else current.union(rect)
      }
    }
    val rects =
      unions.mapIndexedNotNull { index, rect ->
        rect?.let {
          HighlightRect(
            index = index,
            x = PixelUtil.toDIPFromPixel(it.left),
            y = PixelUtil.toDIPFromPixel(it.top),
            width = PixelUtil.toDIPFromPixel(it.width()),
            height = PixelUtil.toDIPFromPixel(it.height()),
          )
        }
      }
    if (rects.size == reportedRects.size && rects.zip(reportedRects).all { (a, b) -> a.isCloseTo(b) }) return
    reportedRects = rects
    onLayout(rects)
  }

  // The view's top-left corner in host pixels, or null when it is not inside the host.
  private fun offsetInHost(view: View): Pair<Float, Float>? {
    var x = 0f
    var y = 0f
    var current: View = view
    while (current !== host) {
      x += current.left + current.translationX - current.scrollX
      y += current.top + current.translationY - current.scrollY
      current = current.parent as? View ?: return null
    }
    return x to y
  }

  /** Forgets the blocks, the highlights and what was reported. */
  fun reset() {
    highlights = emptyList()
    setBlockViews(emptyList())
    reportedRects = emptyList()
  }

  private companion object {
    const val BLOCK_SEPARATOR = "\n"
  }
}
