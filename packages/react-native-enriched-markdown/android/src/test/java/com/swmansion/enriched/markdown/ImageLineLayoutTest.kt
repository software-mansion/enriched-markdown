package com.swmansion.enriched.markdown

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
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
import com.swmansion.enriched.markdown.spans.LinkPillIconCache
import com.swmansion.enriched.markdown.spans.LinkPillSpan
import com.swmansion.enriched.markdown.styles.LinkPillContent
import com.swmansion.enriched.markdown.styles.LinkPillStyle
import com.swmansion.enriched.markdown.styles.LinkVariantEntry
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.test.TestAstFactory.image
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import com.swmansion.enriched.markdown.utils.text.ImageCache
import com.swmansion.enriched.markdown.utils.text.ImageDownloader
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

  // Issue #932: a block image with maxHeight is as tall as maxHeight until the view's width
  // is known. The first layout must use its fitted height, or the image line keeps maxHeight
  // and the text after it overflows the component.
  @Test
  fun aCachedImageIsLaidOutAtItsFittedHeightFromTheFirstLayout() {
    val url = "test://issue-932"
    ImageCache.putOriginal(ImageCache.requestKey(url, emptyMap()), bitmap(800, 100))
    val text =
      SpannableStringBuilder("￼\nafter").apply {
        setSpan(ImageSpan(context, url, fittedImageStyle()), 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
      }
    val view = textView()
    view.setText(text, TextView.BufferType.SPANNABLE)

    measure(view)

    assertEquals(WIDTH * 100 / 800, lineHeight(view.layout, 0))
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

  @Test
  fun aLoadedInlineImageDoesNotLayTheTextOutAgain() {
    val (span, finishLoading) = pendingImage("https://example.com/inline.png", styleConfig(), isInline = true)
    val (view, neighbour) = viewShowing(span)

    finishLoading(bitmap(40, 40))

    assertEquals(0, neighbour.sizeQueries)
    assertEquals(1, view.layout.lineCount)
  }

  @Test
  fun aLoadedBlockImageFillingItsBoxDoesNotLayTheTextOutAgain() {
    val (span, finishLoading) = pendingImage("https://example.com/block.png", styleConfig())
    val (_, neighbour) = viewShowing(span)

    finishLoading(bitmap(800, 100))

    assertEquals(0, neighbour.sizeQueries)
  }

  @Test
  fun aLoadedImageOfAnotherHeightLaysTheTextOutAgain() {
    val (span, finishLoading) = pendingImage("https://example.com/short.png", fittedImageStyle())
    val (view, neighbour) = viewShowing(span)
    assertEquals(IMAGE_HEIGHT, lineHeight(view.layout, 0))

    finishLoading(bitmap(800, 100))

    assertTrue(neighbour.sizeQueries > 0)
    assertEquals(WIDTH * 100 / 800, lineHeight(view.layout, 0))
  }

  @Test
  fun aLoadedPillIconDoesNotLayTheTextOutAgain() {
    val (_, neighbour, finishLoading) = viewShowingPendingPill("https://example.com/icon-loaded.png")

    finishLoading(bitmap(8, 8))

    assertEquals(0, neighbour.sizeQueries)
  }

  @Test
  fun aFailedPillIconLaysTheTextOutAgain() {
    val (_, neighbour, finishLoading) = viewShowingPendingPill("https://example.com/icon-failed.png")

    finishLoading(null)

    assertTrue(neighbour.sizeQueries > 0)
  }

  @Test
  fun redrawingAPillDoesNotLayTheTextOutAgain() {
    val (view, neighbour, _) = viewShowingPendingPill("https://example.com/icon-redrawn.png")

    LinkPillSpan.redraw(view, 0, view.text.length)

    assertEquals(0, neighbour.sizeQueries)
  }

  // Issue #932: the component measures with its own spans. When that happens before the image
  // is cached it reports maxHeight, and only the displayed image can ask it to measure again.
  // These follow the order seen on a device: register, image available, onMeasure, posted check.
  @Test
  fun anImageLoadedBeforeItsViewHasAWidthAsksForARemeasure() {
    val (span, finishLoading) = pendingImage("https://example.com/before-width.png", fittedImageStyle())
    val view = viewAwaitingLayout(span)
    var remeasures = 0
    span.registerTextView(view) { remeasures++ }

    finishLoading(bitmap(800, 100))
    measure(view)
    view.runPostedActions()

    assertEquals(1, remeasures)
  }

  @Test
  fun aCachedImageAsksForARemeasureOnceItsViewHasAWidth() {
    val url = "test://issue-932-remeasure"
    ImageCache.putOriginal(ImageCache.requestKey(url, emptyMap()), bitmap(800, 100))
    val span = ImageSpan(context, url, fittedImageStyle())
    val view = viewAwaitingLayout(span)
    var remeasures = 0
    span.registerTextView(view) { remeasures++ }

    measure(view)
    view.runPostedActions()

    assertEquals(1, remeasures)
  }

  @Test
  fun anImageFittedBeforeItsLoadFinishesAsksForARemeasure() {
    val url = "https://example.com/fitted-early.png"
    val (span, finishLoading) = pendingImage(url, fittedImageStyle())
    val view = viewAwaitingLayout(span)
    var remeasures = 0
    span.registerTextView(view) { remeasures++ }
    measure(view)
    view.runPostedActions()
    remeasures = 0

    // The download caches the image before its callback reaches the main thread.
    val image = bitmap(800, 100)
    ImageCache.putOriginal(ImageCache.requestKey(url, emptyMap()), image)
    view.requestLayout()
    measure(view)
    finishLoading(image)

    assertEquals(1, remeasures)
    assertEquals(WIDTH * 100 / 800, lineHeight(view.layout, 0))
  }

  @Test
  fun anImageAsksForARemeasureOnlyOnceWhenRegisteredAgain() {
    val url = "test://issue-932-registered-again"
    ImageCache.putOriginal(ImageCache.requestKey(url, emptyMap()), bitmap(800, 100))
    val span = ImageSpan(context, url, fittedImageStyle())
    val view = viewAwaitingLayout(span)
    var remeasures = 0
    span.registerTextView(view) { remeasures++ }
    measure(view)
    view.runPostedActions()

    span.registerTextView(view) { remeasures++ }
    view.runPostedActions()

    assertEquals(1, remeasures)
  }

  @Test
  fun anUnloadedImageDoesNotAskForARemeasureAtRegistration() {
    val (span, _) = pendingImage("https://example.com/never-loads.png", fittedImageStyle())
    val view = viewAwaitingLayout(span)
    var remeasures = 0
    span.registerTextView(view) { remeasures++ }
    measure(view)
    view.runPostedActions()

    assertEquals(0, remeasures)
  }

  private fun fittedImageStyle() = styleConfig(image = mapOf("maxHeight" to IMAGE_HEIGHT.toDouble(), "resizeMode" to "contain"))

  /** A view showing [span] that has not been measured yet, as one is when it is created. */
  private fun viewAwaitingLayout(span: ImageSpan): PostHoldingTextView {
    val text =
      SpannableStringBuilder("￼\nafter").apply {
        setSpan(span, 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
      }
    return PostHoldingTextView(context).apply {
      layoutParams = ViewGroup.LayoutParams(WIDTH, ViewGroup.LayoutParams.WRAP_CONTENT)
      setupAsMarkdownTextView()
      setText(text, TextView.BufferType.SPANNABLE)
    }
  }

  /** An image whose download is in flight, and what finishes that download. */
  private fun pendingImage(
    url: String,
    style: StyleConfig,
    isInline: Boolean = false,
  ): Pair<ImageSpan, (Bitmap?) -> Unit> {
    var finishLoading: (Bitmap?) -> Unit = {}
    val realLoader = ImageDownloader.remoteLoader
    ImageDownloader.remoteLoader = { _, _, _, onLoaded -> finishLoading = onLoaded }
    val span =
      try {
        ImageSpan(context, url, style, isInline)
      } finally {
        ImageDownloader.remoteLoader = realLoader
      }
    return span to finishLoading
  }

  /** A laid out view with [span] and a span that counts how often the paragraph is measured. */
  private fun viewShowing(span: ImageSpan): Pair<TextView, ResizableSpan> {
    val neighbour = ResizableSpan(width = 0)
    val text =
      SpannableStringBuilder("￼ words ￼").apply {
        setSpan(span, 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        setSpan(neighbour, length - 1, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
      }
    val view = textView()
    view.setText(text, TextView.BufferType.SPANNABLE)
    measure(view)
    span.registerTextView(view)
    neighbour.sizeQueries = 0
    return view to neighbour
  }

  /** A laid out view with a pill whose icon is downloading, a span that counts paragraph measures, and what ends the download. */
  private fun viewShowingPendingPill(iconUrl: String): Triple<TextView, ResizableSpan, (Bitmap?) -> Unit> {
    var finishLoading: (Bitmap?) -> Unit = {}
    val realLoader = LinkPillIconCache.remoteLoader
    LinkPillIconCache.remoteLoader = { _, _, _, onLoaded -> finishLoading = onLoaded }
    val pill =
      try {
        LinkPillSpan(
          LinkVariantEntry("", Color.BLACK, false, Color.TRANSPARENT, pill = LinkPillStyle()),
          Typeface.DEFAULT,
          14f,
          "pill",
          context,
          LinkPillContent(iconUri = iconUrl),
        )
      } finally {
        LinkPillIconCache.remoteLoader = realLoader
      }
    val neighbour = ResizableSpan(width = 0)
    val text =
      SpannableStringBuilder("pill words ￼").apply {
        setSpan(pill, 0, 4, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        setSpan(neighbour, length - 1, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
      }
    val view = textView()
    view.setText(text, TextView.BufferType.SPANNABLE)
    measure(view)
    neighbour.sizeQueries = 0
    return Triple(view, neighbour, finishLoading)
  }

  private fun bitmap(
    width: Int,
    height: Int,
  ) = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)

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

  /** Holds what is posted to it, because a view outside a window would never run it. */
  private class PostHoldingTextView(
    context: Context,
  ) : AccessibleMarkdownTextView(context) {
    private val posted = mutableListOf<Runnable>()

    override fun post(action: Runnable): Boolean = posted.add(action)

    fun runPostedActions() {
      val actions = posted.toList()
      posted.clear()
      actions.forEach { it.run() }
    }
  }

  private class ResizableSpan(
    var width: Int,
  ) : ReplacementSpan() {
    var sizeQueries = 0

    override fun getSize(
      paint: Paint,
      text: CharSequence?,
      start: Int,
      end: Int,
      fm: Paint.FontMetricsInt?,
    ): Int {
      sizeQueries++
      return width
    }

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
