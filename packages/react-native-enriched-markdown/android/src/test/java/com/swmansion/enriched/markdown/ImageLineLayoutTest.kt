package com.swmansion.enriched.markdown

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.text.Layout
import android.text.Spannable
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.StaticLayout
import android.text.TextPaint
import android.text.style.ReplacementSpan
import android.view.View.MeasureSpec
import android.view.ViewGroup
import android.widget.TextView
import com.swmansion.enriched.markdown.accessibility.AccessibleMarkdownTextView
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.test.TestAstFactory.image
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import com.swmansion.enriched.markdown.utils.text.span.prepareWidthAwareSpans
import com.swmansion.enriched.markdown.utils.text.view.setupAsMarkdownTextView
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

// Issue #1122: words after an image that opens a line were laid out as if the image had
// no width, then pushed past the view's edge when it drew at its real width.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ImageLineLayoutTest {
  private val context: Context get() = RuntimeEnvironment.getApplication()

  @Test
  fun wordsAfterAnImageMoveToTheirOwnLine() {
    val layout = measuredLayout(imageThenWords("list picture"))

    assertEquals(2, layout.lineCount)
    assertEquals("list picture", lineText(layout, 1))
  }

  @Test
  fun onlyTheImageLineIsAsTallAsTheImage() {
    val words = List(40) { "w$it" }.joinToString(" ")
    val layout = measuredLayout(imageThenWords(words))

    assertTrue(layout.lineCount > 2)
    assertEquals(IMAGE_HEIGHT, lineHeight(layout, 0))
    val plain = plainLineHeight()
    for (line in 1 until layout.lineCount) {
      assertEquals("line $line", plain, lineHeight(layout, line))
    }
  }

  @Test
  fun aListItemKeepsItsLinesApartFromTheImageHeight() {
    val rendered =
      render(
        styleConfig(),
        unorderedList(
          listItem(paragraph(image(), text(" list picture"))),
          listItem(paragraph(text("plain item"))),
        ),
      )
    val layout = measuredLayout(rendered)

    assertEquals(IMAGE_HEIGHT, lineHeight(layout, 0))
    val pictureLine = (0 until layout.lineCount).single { lineText(layout, it).contains("list picture") }
    val plainItemLine = (0 until layout.lineCount).single { lineText(layout, it).contains("plain item") }
    assertTrue(lineHeight(layout, pictureLine) < IMAGE_HEIGHT)
    assertEquals(lineHeight(layout, plainItemLine), lineHeight(layout, pictureLine))
  }

  @Test
  fun aTextViewSizesTheImageBeforeBuildingItsFirstLayout() {
    val view = textView()
    view.setText(imageThenWords("list picture"), TextView.BufferType.SPANNABLE)
    measure(view)

    assertEquals("list picture", lineText(view.layout, 1))
  }

  @Test
  fun aTextViewKeepsTheImageInsideItsPadding() {
    val view = textView().apply { setPadding(0, 0, 1, 0) }
    val text = imageThenWords("list picture")
    val span = text.getSpans(0, text.length, ImageSpan::class.java).single()
    view.layout(0, 0, WIDTH, 200)

    span.registerTextView(view)

    assertEquals(WIDTH - 1, span.getSize(TextPaint(), text, 0, 1, null))
  }

  @Test
  fun aNewWidthDropsALayoutBuiltForTheOldOne() {
    val view = textView()
    view.setText(imageThenWords("list picture"), TextView.BufferType.SPANNABLE)
    measure(view)
    val before = view.layout

    measure(view, WIDTH * 2)

    assertFalse(before === view.layout)
    val span = (view.text as Spanned).let { it.getSpans(0, it.length, ImageSpan::class.java).single() }
    assertEquals(WIDTH * 2, span.getSize(TextPaint(), view.text, 0, 1, null))
  }

  @Test
  fun settingASpanAgainReflowsTheTextViewsLayout() {
    val span = ResizableSpan(width = 0)
    val text = SpannableStringBuilder("￼ words").apply { setSpan(span, 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE) }
    val view = textView()
    view.setText(text, TextView.BufferType.SPANNABLE)
    measure(view)
    assertEquals(1, view.layout.lineCount)

    span.width = WIDTH
    (view.text as Spannable).setSpan(span, 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)

    assertEquals(2, view.layout.lineCount)
  }

  private fun textView() =
    object : AccessibleMarkdownTextView(context) {}.apply {
      layoutParams = ViewGroup.LayoutParams(WIDTH, ViewGroup.LayoutParams.WRAP_CONTENT)
      setupAsMarkdownTextView()
    }

  private fun measure(
    view: TextView,
    width: Int = WIDTH,
  ) {
    view.measure(
      MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED),
    )
    view.layout(0, 0, view.measuredWidth, view.measuredHeight)
  }

  private fun imageThenWords(words: String): SpannableStringBuilder =
    SpannableStringBuilder("￼ $words").apply {
      setSpan(ImageSpan(context, "", styleConfig()), 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }

  private fun measuredLayout(text: CharSequence): Layout {
    prepareWidthAwareSpans(text, WIDTH)
    return StaticLayout.Builder
      .obtain(text, 0, text.length, TextPaint(), WIDTH)
      .setIncludePad(false)
      .build()
  }

  private fun plainLineHeight(): Int = measuredLayout("plain").let { lineHeight(it, 0) }

  private fun lineHeight(
    layout: Layout,
    line: Int,
  ): Int = layout.getLineBottom(line) - layout.getLineTop(line)

  private fun lineText(
    layout: Layout,
    line: Int,
  ): String =
    layout.text
      .subSequence(layout.getLineStart(line), layout.getLineEnd(line))
      .toString()
      .trim()

  private class ResizableSpan(
    var width: Int,
  ) : ReplacementSpan() {
    override fun getSize(
      paint: Paint,
      text: CharSequence?,
      start: Int,
      end: Int,
      fm: Paint.FontMetricsInt?,
    ): Int = width

    override fun draw(
      canvas: Canvas,
      text: CharSequence?,
      start: Int,
      end: Int,
      x: Float,
      top: Int,
      y: Int,
      bottom: Int,
      paint: Paint,
    ) = Unit
  }

  private companion object {
    const val WIDTH = 400
    const val IMAGE_HEIGHT = 100
  }
}
