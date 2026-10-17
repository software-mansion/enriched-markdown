package com.swmansion.enriched.markdown

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Region
import android.util.TypedValue
import android.view.View
import androidx.test.core.app.ApplicationProvider
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.blockquote
import com.swmansion.enriched.markdown.test.TestAstFactory.codeBlock
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.ParameterizedRobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Covers the box a code block paints, wherever the block sits. A list item trims its trailing
 * newlines, so a block that ends one loses its own '\n' and must still close its box.
 */
@RunWith(ParameterizedRobolectricTestRunner::class)
@Config(sdk = [28])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class CodeBlockPaintingTest(
  private val placement: Placement,
) {
  private val context: Context = ApplicationProvider.getApplicationContext()

  enum class Placement {
    TOP_LEVEL {
      override fun wrap(block: MarkdownASTNode) = document(block, paragraph(text("after")))
    },
    IN_BLOCKQUOTE {
      override fun wrap(block: MarkdownASTNode) = document(blockquote(block), paragraph(text("after")))
    },
    ENDING_LIST_ITEM {
      override fun wrap(block: MarkdownASTNode) =
        document(unorderedList(listItem(paragraph(text("item")), block), listItem(paragraph(text("next")))))
    },
    ENDING_BLOCKQUOTE_IN_LIST_ITEM {
      override fun wrap(block: MarkdownASTNode) =
        document(unorderedList(listItem(paragraph(text("item")), blockquote(block)), listItem(paragraph(text("next")))))
    }, ;

    abstract fun wrap(block: MarkdownASTNode): MarkdownASTNode
  }

  companion object {
    private const val WIDTH = 400
    private const val BACKGROUND = 0xFF224488.toInt()

    // Tall enough that a padded line outgrows any container line height, which only ever adds leading.
    private const val PADDING = 24f
    private const val RADIUS = 8f

    @JvmStatic
    @ParameterizedRobolectricTestRunner.Parameters(name = "{0}")
    fun placements() = Placement.entries.map { arrayOf(it) }
  }

  /** Records the code block's per-line [BACKGROUND] fills, without painting anything. */
  private class RecordingCanvas(
    bitmap: Bitmap,
  ) : Canvas(bitmap) {
    val backgrounds = mutableListOf<Path>()

    override fun drawPath(
      path: Path,
      paint: Paint,
    ) {
      if (paint.style == Paint.Style.FILL && paint.color == BACKGROUND) backgrounds.add(Path(path))
    }
  }

  private fun drawBackgrounds(padding: Float): List<Path> {
    val style =
      MarkdownRenderTestSupport.styleWithCodeBlock(
        MarkdownRenderTestSupport.defaultStyle.codeBlockStyle.copy(
          backgroundColor = BACKGROUND,
          borderWidth = 0f,
          borderRadius = RADIUS,
          padding = padding,
        ),
      )
    val rendered = render(placement.wrap(codeBlock("first\nlast\n")), style)
    val textView = EnrichedMarkdownInternalText(context)
    textView.setTextSize(TypedValue.COMPLEX_UNIT_PX, style.paragraphStyle.fontSize)
    textView.text = rendered
    textView.measure(
      View.MeasureSpec.makeMeasureSpec(WIDTH, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    textView.layout(0, 0, WIDTH, textView.measuredHeight)

    val canvas = RecordingCanvas(Bitmap.createBitmap(WIDTH, maxOf(textView.height, 1), Bitmap.Config.ARGB_8888))
    requireNotNull(textView.layout).draw(canvas)
    assertEquals("Expected one background per code line", 2, canvas.backgrounds.size)
    return canvas.backgrounds
  }

  private fun Path.bounds(): RectF = RectF().also { computeBounds(it, true) }

  private fun Path.covers(
    x: Float,
    y: Float,
  ): Boolean {
    val clip = Rect().also { bounds().roundOut(it) }
    return Region().apply { setPath(this@covers, Region(clip)) }.contains(x.toInt(), y.toInt())
  }

  @Test
  fun padsBothTheTopAndTheBottomOfTheBox() {
    fun boxHeight(backgrounds: List<Path>) = backgrounds.last().bounds().bottom - backgrounds.first().bounds().top

    // Measured against a smaller padding rather than none: an unpadded line would take leading from
    // the container's line height and skew the difference.
    assertEquals(2 * PADDING, boxHeight(drawBackgrounds(2 * PADDING)) - boxHeight(drawBackgrounds(PADDING)), 0.5f)
  }

  @Test
  fun roundsOnlyTheOuterCornersOfTheBox() {
    val (first, last) = drawBackgrounds(PADDING)
    val top = first.bounds()
    val bottom = last.bounds()

    assertFalse("The top-left corner must be rounded", first.covers(top.left + 1, top.top + 1))
    assertTrue("The first line's bottom-left corner must be square", first.covers(top.left + 1, top.bottom - 1))
    assertTrue("The last line's top-left corner must be square", last.covers(bottom.left + 1, bottom.top + 1))
    assertFalse("The bottom-left corner must be rounded", last.covers(bottom.left + 1, bottom.bottom - 1))
  }
}
