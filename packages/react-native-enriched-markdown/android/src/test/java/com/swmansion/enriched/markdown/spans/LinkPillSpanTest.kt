package com.swmansion.enriched.markdown.spans

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.text.SpannableString
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.StaticLayout
import android.text.TextPaint
import android.util.Base64
import android.view.View
import android.widget.TextView
import com.facebook.react.bridge.JavaOnlyArray
import com.facebook.react.bridge.JavaOnlyMap
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.swmansion.enriched.markdown.accessibility.MarkdownAccessibilityHelper
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.renderer.BlockStyle
import com.swmansion.enriched.markdown.renderer.LinkRenderer
import com.swmansion.enriched.markdown.renderer.RendererConfig
import com.swmansion.enriched.markdown.renderer.RendererFactory
import com.swmansion.enriched.markdown.renderer.SpanStyleCache
import com.swmansion.enriched.markdown.styles.LinkVariantEntry
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.StyleParser
import com.swmansion.enriched.markdown.utils.text.LocalImageLoader
import com.swmansion.enriched.markdown.utils.text.conversion.MarkdownExtractor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class LinkPillSpanTest {
  private val original = "Original Markdown label"
  private val style = LinkVariantEntry("^https:", Color.BLUE, false, Color.LTGRAY, pill = true, label = "Visual", borderWidth = 1f)
  private val paint =
    TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
      textSize = 16f
      typeface = Typeface.DEFAULT
    }

  private fun span(variant: LinkVariantEntry = style) =
    LinkPillSpan(variant, Typeface.DEFAULT, 16f, original, RuntimeEnvironment.getApplication())

  private fun writeIcon(
    file: File,
    color: Int = Color.RED,
  ) {
    val bitmap = Bitmap.createBitmap(16, 16, Bitmap.Config.ARGB_8888)
    bitmap.eraseColor(color)
    for (y in 0 until 16) {
      for (x in 8 until 16) bitmap.setPixel(x, y, Color.GREEN)
      for (x in 0 until 16) bitmap.setPixel(x, 0, Color.TRANSPARENT)
      for (x in 0 until 16) {
        if (y in 4..6) bitmap.setPixel(x, y, Color.TRANSPARENT)
        if (y in 11..13) bitmap.setPixel(x, y, Color.argb(128, 255, 0, 0))
      }
    }
    file.outputStream().use { assertTrue("PNG encoding", bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) }
    assertTrue("PNG bytes", file.length() > 0)
  }

  private fun drawIcon(
    uri: String,
    tint: Int?,
  ): Bitmap {
    val bitmap = Bitmap.createBitmap(120, 40, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val iconTop = 24 + (paint.fontMetrics.ascent + paint.fontMetrics.descent - 16) / 2
    // Align the bitmap destination, avoiding fractional resampling differences between Skia paths.
    canvas.translate(0f, kotlin.math.floor(iconTop) - iconTop)
    span(
      style.copy(
        iconUri = uri,
        iconTintColor = tint,
        paddingHorizontal = 0f,
        borderWidth = 0f,
        backgroundColor = Color.TRANSPARENT,
      ),
    ).draw(canvas, original, 0, original.length, 0f, 0, 24, 40, paint)
    return bitmap
  }

  @Test
  fun iconTintPreservesAlphaAndLeavesCachedOriginalColorsUnchanged() {
    val file = File.createTempFile("enriched-icon", ".png")
    try {
      writeIcon(file)
      val uri = file.toURI().toString()
      val cached = LinkPillIconCache.load(RuntimeEnvironment.getApplication(), uri)!!
      val before = drawIcon(uri, null)
      val tinted = drawIcon(uri, Color.BLUE)
      val translucent = drawIcon(uri, Color.argb(128, 0, 0, 255))
      val transparent = drawIcon(uri, Color.TRANSPARENT)
      val after = drawIcon(uri, null)
      assertSame(cached, LinkPillIconCache.load(RuntimeEnvironment.getApplication(), uri))
      assertEquals(Color.RED, cached.getPixel(2, 8))
      assertEquals(Color.GREEN, cached.getPixel(12, 8))
      assertTrue(pixels(before).contentEquals(pixels(after)))
      val iconTop = kotlin.math.floor(24 + (paint.fontMetrics.ascent + paint.fontMetrics.descent - 16) / 2)
      val centerY = (iconTop + 8).toInt()
      assertEquals(Color.RED, before.getPixel(2, centerY))
      assertEquals(Color.GREEN, before.getPixel(12, centerY))
      assertEquals(Color.BLUE, tinted.getPixel(2, centerY))
      assertEquals(Color.BLUE, tinted.getPixel(12, centerY))
      assertEquals(128, Color.alpha(translucent.getPixel(2, centerY)))
      assertEquals(Color.TRANSPARENT, transparent.getPixel(2, centerY))
      assertEquals(128, Color.alpha(tinted.getPixel(2, (iconTop + 12).toInt())))
      assertEquals(Color.TRANSPARENT, tinted.getPixel(2, (iconTop + 5).toInt()))
      assertEquals(64, Color.alpha(translucent.getPixel(2, (iconTop + 12).toInt())))
      // Flat regions verify image alpha independently of fractional resampling at transitions.
      for (offset in listOf(2, 5, 8, 12)) {
        val y = (iconTop + offset).toInt()
        for (x in 1 until 15) {
          assertEquals(Color.alpha(before.getPixel(x, y)), Color.alpha(tinted.getPixel(x, y)))
        }
      }
      for (y in 0 until 40) {
        for (x in 0 until 16) {
          if (Color.alpha(tinted.getPixel(x, y)) > 0) {
            assertEquals(0, Color.red(tinted.getPixel(x, y)))
            assertEquals(0, Color.green(tinted.getPixel(x, y)))
            assertEquals(255, Color.blue(tinted.getPixel(x, y)))
          }
        }
      }
    } finally {
      file.delete()
    }
  }

  @Test
  fun tintTransportDistinguishesMissingAndTransparentAndParticipatesInHash() {
    val parser = StyleParser(RuntimeEnvironment.getApplication(), false, 1f)
    val map =
      JavaOnlyMap.of(
        "pattern",
        "^app:",
        "color",
        Color.BLACK.toDouble(),
        "underline",
        false,
        "backgroundColor",
        0.0,
        "fontFamily",
        "",
        "label",
        "",
        "iconUri",
        "",
      )
    val absent = LinkVariantEntry.fromReadableMap(map, parser)
    assertEquals(null, absent.iconTintColor)
    map.putDouble("iconTintColor", 0.0)
    val clear = LinkVariantEntry.fromReadableMap(map, parser)
    assertEquals(Color.TRANSPARENT, clear.iconTintColor)
    map.putDouble("iconTintColor", Color.BLUE.toDouble())
    val blue = LinkVariantEntry.fromReadableMap(map, parser)
    assertEquals(Color.BLUE, blue.iconTintColor)
    assertNotEquals(absent, clear)
    assertNotEquals(clear.hashCode(), blue.hashCode())
  }

  @Test
  fun iconCacheInvalidatesModifiedFilesAndBoundsEntryCountWithoutRecyclingOwners() {
    val files = mutableListOf<File>()
    try {
      val file = File.createTempFile("enriched-cache", ".png").also { files.add(it) }
      writeIcon(file)
      val uri = file.toURI().toString()
      val first = LinkPillIconCache.load(RuntimeEnvironment.getApplication(), uri)!!
      assertSame(first, LinkPillIconCache.load(RuntimeEnvironment.getApplication(), uri))
      val modified = file.lastModified()
      writeIcon(file, Color.BLUE)
      assertTrue(file.setLastModified(modified + 2000))
      val updated = LinkPillIconCache.load(RuntimeEnvironment.getApplication(), uri)!!
      assertNotSame(first, updated)
      assertEquals(Color.BLUE, updated.getPixel(2, 8))
      repeat(64) {
        val next = File.createTempFile("enriched-cache", ".png").also { files.add(it) }
        writeIcon(next)
        LinkPillIconCache.load(RuntimeEnvironment.getApplication(), next.toURI().toString())
      }
      assertNotSame(updated, LinkPillIconCache.load(RuntimeEnvironment.getApplication(), uri))
      assertFalse(updated.isRecycled)
      assertEquals(Color.RED, first.getPixel(2, 8))
    } finally {
      files.forEach { it.delete() }
    }
  }

  @Test
  fun iconCacheBoundsPixelMemoryAndSamplesOversizedIcons() {
    val files = mutableListOf<File>()
    try {
      var first: Bitmap? = null
      repeat(9) {
        val file = File.createTempFile("enriched-large-icon", ".png").also { files.add(it) }
        val source = Bitmap.createBitmap(1024, 1024, Bitmap.Config.ARGB_8888)
        source.eraseColor(Color.RED)
        file.outputStream().use { assertTrue(source.compress(Bitmap.CompressFormat.PNG, 100, it)) }
        source.recycle()
        val decoded = LinkPillIconCache.load(RuntimeEnvironment.getApplication(), file.toURI().toString())!!
        assertTrue(decoded.width <= 512 && decoded.height <= 512)
        if (it == 0) first = decoded
      }
      assertNotSame(first, LinkPillIconCache.load(RuntimeEnvironment.getApplication(), files.first().toURI().toString()))
      assertFalse(first!!.isRecycled)
    } finally {
      files.forEach { it.delete() }
    }
  }

  @Test
  fun preservesOriginalCharactersAndAccessibilityLabel() {
    val pill = span()
    val text = SpannableString(original)
    text.setSpan(pill, 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    assertEquals(original, text.toString())
    assertEquals("Visual, $original", pill.contentDescription)
    assertFalse(text.toString().contains('\uFFFC'))
  }

  @Test
  fun accessibleLinkNodeIncludesVisibleAndOriginalText() {
    val context = RuntimeEnvironment.getApplication()
    val config = testStyleConfig(true)
    val factory = RendererFactory(RendererConfig(config), context) {}
    factory.blockStyleContext.setParagraphStyle(config.paragraphStyle)
    val text = SpannableStringBuilder()
    val node =
      MarkdownASTNode(
        MarkdownASTNode.NodeType.Link,
        attributes = mapOf("url" to "https://example.com/original"),
        children = listOf(MarkdownASTNode(MarkdownASTNode.NodeType.Text, original)),
      )
    LinkRenderer(RendererConfig(config)).render(node, text, null, null, factory)
    factory.flushDeferredSpans(text)
    val view = TextView(context)
    view.text = text
    view.measure(
      View.MeasureSpec.makeMeasureSpec(300, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(100, View.MeasureSpec.EXACTLY),
    )
    view.layout(0, 0, 300, 100)
    val helper = MarkdownAccessibilityHelper(view)
    helper.invalidateAccessibilityItems()
    val accessible = helper.getAccessibilityNodeProvider(view)!!.createAccessibilityNodeInfo(0)!!
    assertEquals("Visual label, $original", accessible.text.toString())
    assertEquals(original, view.text.toString())
    assertEquals(original, span(style.copy(label = "")).accessibilityText)
    assertEquals(original, span(style.copy(label = original)).accessibilityText)
    helper.cleanup()
  }

  @Test
  fun localDataIconsDownsampleBothAxesWithoutChangingOrdinaryImagePolicy() {
    val source = Bitmap.createBitmap(32, 2048, Bitmap.Config.ARGB_8888)
    source.eraseColor(Color.RED)
    val bytes = java.io.ByteArrayOutputStream()
    assertTrue(source.compress(Bitmap.CompressFormat.PNG, 100, bytes))
    source.recycle()
    val uri = "data:image/png;base64," + Base64.encodeToString(bytes.toByteArray(), Base64.NO_WRAP)
    val decoded = LinkPillIconCache.load(RuntimeEnvironment.getApplication(), uri)!!
    assertTrue(decoded.width <= 512 && decoded.height <= 512)
    assertEquals(Color.RED, decoded.getPixel(0, 0))
    val ordinaryImage = LocalImageLoader.load(RuntimeEnvironment.getApplication(), uri)!!
    assertEquals(2048, ordinaryImage.height)
    assertSame(decoded, LinkPillIconCache.load(RuntimeEnvironment.getApplication(), uri))
  }

  @Test
  fun measuresPresentationLabelAndClampsToAvailableAndExplicitWidth() {
    val pill = span(style.copy(label = "A very long presentation label", maxWidth = 100f))
    pill.prepareForMeasurement(200)
    assertEquals(100, pill.getSize(paint, original, 0, original.length, null))
    pill.prepareForMeasurement(60)
    assertEquals(60, pill.getSize(paint, original, 0, original.length, null))
  }

  @Test
  fun shortVisualLabelHasLessWidthThanOriginalFallback() {
    val short = span(style.copy(label = "X"))
    val fallback = span(style.copy(label = ""))
    assertTrue(short.getSize(paint, original, 0, original.length, null) < fallback.getSize(paint, original, 0, original.length, null))
  }

  @Test
  fun paddingAndBorderExpandFontMetricsWithoutMutatingPaint() {
    val pill = span(style.copy(paddingVertical = 8f, borderWidth = 2f))
    val metrics = paint.fontMetricsInt
    val before = paint.fontMetricsInt
    pill.getSize(paint, original, 0, original.length, metrics)
    assertTrue(metrics.ascent <= before.ascent - 10)
    assertTrue(metrics.descent >= before.descent + 10)
    assertEquals(16f, paint.textSize, 0f)
    assertEquals(Typeface.DEFAULT, paint.typeface)
  }

  @Test
  fun layoutWrapsWholePillAndRetainsOriginalSelectionText() {
    val text = SpannableString("before $original after")
    val start = "before ".length
    val pill = span(style.copy(label = "A long visual label", maxWidth = 80f))
    text.setSpan(pill, start, start + original.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    LinkPillSpan.prepareForMeasurement(text, 90)
    val layout =
      StaticLayout.Builder
        .obtain(text, 0, text.length, paint, 90)
        .setIncludePad(false)
        .build()
    assertTrue(layout.lineCount > 1)
    for (line in 0 until layout.lineCount - 1) {
      val end = layout.getLineEnd(line)
      assertFalse("Pill was split at $end", end > start && end < start + original.length)
    }
    assertEquals(original, text.subSequence(start, start + original.length).toString())
  }

  @Test
  fun invalidOrRemoteIconFallsBackWithoutNetworkOrExceptions() {
    for (uri in listOf("file:///does-not-exist.png", "https://example.com/icon.png", "")) {
      val pill = span(style.copy(iconUri = uri))
      pill.prepareForMeasurement(30)
      assertEquals(30, pill.getSize(paint, original, 0, original.length, null))
      pill.draw(Canvas(), original, 0, original.length, 0f, 0, 20, 40, paint)
    }
  }

  @Test
  fun rendererKeepsOriginalLinkCallbacksAndMarkdownExtractionWithPresentationLabel() {
    val context = RuntimeEnvironment.getApplication()
    val config = testStyleConfig(true)
    val factory = RendererFactory(RendererConfig(config), context) {}
    factory.blockStyleContext.setParagraphStyle(config.paragraphStyle)
    val builder = SpannableStringBuilder()
    val url = "https://example.com/original"
    val presses = mutableListOf<String>()
    val longPresses = mutableListOf<String>()
    val node =
      MarkdownASTNode(
        MarkdownASTNode.NodeType.Link,
        attributes = mapOf("url" to url),
        children = listOf(MarkdownASTNode(MarkdownASTNode.NodeType.Text, original)),
      )
    LinkRenderer(RendererConfig(config)).render(node, builder, { presses.add(it) }, { longPresses.add(it) }, factory)
    factory.flushDeferredSpans(builder)
    assertEquals(original, builder.toString())
    assertEquals(1, builder.getSpans(0, builder.length, LinkPillSpan::class.java).size)
    assertEquals("[$original]($url)", MarkdownExtractor.extractFromSpannable(builder, 0, builder.length))
    val link = builder.getSpans(0, builder.length, LinkSpan::class.java).single()
    val view = TextView(context)
    link.onClick(view)
    link.onLongClick(view)
    link.onClick(view)
    assertEquals(listOf(url), presses)
    assertEquals(listOf(url), longPresses)
  }

  @Test
  fun pillInheritsTheSameBlockFontWeightAndSizeAsTheOrdinaryLink() {
    val context = RuntimeEnvironment.getApplication()
    val label = "MMMMWW"
    val config = testStyleConfig(true, presentationLabel = label)
    val factory = RendererFactory(RendererConfig(config), context) {}
    factory.blockStyleContext.setParagraphStyle(config.paragraphStyle.copy(fontWeight = "bold", fontSize = 24f))
    val builder = SpannableStringBuilder()
    val node =
      MarkdownASTNode(
        MarkdownASTNode.NodeType.Link,
        attributes = mapOf("url" to "https://example.com"),
        children = listOf(MarkdownASTNode(MarkdownASTNode.NodeType.Text, original)),
      )
    LinkRenderer(RendererConfig(config)).render(node, builder, null, null, factory)
    factory.flushDeferredSpans(builder)
    val ordinaryPaint = TextPaint(paint)
    builder.getSpans(0, builder.length, LinkSpan::class.java).single().updateDrawState(ordinaryPaint)
    assertTrue(ordinaryPaint.typeface.isBold)
    assertEquals(24f, ordinaryPaint.textSize, 0f)
    val pill = builder.getSpans(0, builder.length, LinkPillSpan::class.java).single()
    pill.prepareForMeasurement(1000)
    assertEquals(
      kotlin.math.ceil(ordinaryPaint.measureText(label) + 12f).toInt(),
      pill.getSize(paint, builder, 0, builder.length, null),
    )
  }

  @Test
  fun existingNonPillVariantsKeepOrdinaryLinks() {
    val context = RuntimeEnvironment.getApplication()
    val config = testStyleConfig(false)
    val factory = RendererFactory(RendererConfig(config), context) {}
    factory.blockStyleContext.setParagraphStyle(config.paragraphStyle)
    val builder = SpannableStringBuilder()
    val node =
      MarkdownASTNode(
        MarkdownASTNode.NodeType.Link,
        attributes = mapOf("url" to "https://example.com"),
        children = listOf(MarkdownASTNode(MarkdownASTNode.NodeType.Text, original)),
      )
    LinkRenderer(RendererConfig(config)).render(node, builder, null, null, factory)
    factory.flushDeferredSpans(builder)
    assertEquals(original, builder.toString())
    assertTrue(builder.getSpans(0, builder.length, LinkPillSpan::class.java).isEmpty())
    assertEquals(1, builder.getSpans(0, builder.length, LinkSpan::class.java).size)
  }

  @Test
  fun inlineCodePillSuppressesOpaqueCodeBackgroundAndPreservesExtraction() {
    val context = RuntimeEnvironment.getApplication()
    val config = testStyleConfig(true, Color.RED, "file.ts")
    val factory = RendererFactory(RendererConfig(config), context) {}
    factory.blockStyleContext.setParagraphStyle(config.paragraphStyle)
    val builder = SpannableStringBuilder()
    val path = "src/a/really/long/original/document/file.ts"
    val url = "https://example.com/file"
    val node =
      MarkdownASTNode(
        MarkdownASTNode.NodeType.Link,
        attributes = mapOf("url" to url),
        children =
          listOf(
            MarkdownASTNode(
              MarkdownASTNode.NodeType.Code,
              children = listOf(MarkdownASTNode(MarkdownASTNode.NodeType.Text, path)),
            ),
          ),
      )
    LinkRenderer(RendererConfig(config)).render(node, builder, null, null, factory)
    factory.flushDeferredSpans(builder)
    assertEquals(path, builder.toString())
    val code = builder.getSpans(0, builder.length, CodeSpan::class.java).single()
    val background = builder.getSpans(0, builder.length, CodeBackgroundSpan::class.java).single()
    val pill = builder.getSpans(0, builder.length, LinkPillSpan::class.java).single()
    LinkPillSpan.prepareForMeasurement(builder, 240)
    val originalMarkdown = MarkdownExtractor.extractFromSpannable(builder, 0, builder.length)
    assertEquals("[$path]($url)", originalMarkdown)

    val bitmap = Bitmap.createBitmap(240, 40, Bitmap.Config.ARGB_8888)
    background.drawBackground(Canvas(bitmap), paint, 0, 240, 0, 24, 40, builder, 0, builder.length, 0)
    assertTrue("Covered code background must not paint outside rounded pill", pixels(bitmap).all { it == Color.TRANSPARENT })
    assertEquals(0, builder.getSpanStart(code))
    assertEquals(path.length, builder.getSpanEnd(code))

    // Removing only presentation must leave the same Markdown and restore ordinary code painting.
    builder.removeSpan(pill)
    assertEquals(originalMarkdown, MarkdownExtractor.extractFromSpannable(builder, 0, builder.length))
    background.drawBackground(Canvas(bitmap), paint, 0, 240, 0, 24, 40, builder, 0, builder.length, 0)
    assertTrue("Ordinary inline code still paints its configured background", pixels(bitmap).any { it == Color.RED })

    // Recognition's synthetic-link suppression can still recover the original inline-code mark.
    builder.removeSpan(builder.getSpans(0, builder.length, LinkSpan::class.java).single())
    assertEquals("`$path`", MarkdownExtractor.extractFromSpannable(builder, 0, builder.length))
  }

  @Test
  fun partialPillCoverageKeepsCodeBackgroundOnBothSides() {
    val config = testStyleConfig(true, Color.RED)
    val text = SpannableString("left original long path right")
    val start = "left ".length
    val end = text.length - " right".length
    val background = CodeBackgroundSpan(config)
    val pill =
      LinkPillSpan(
        style.copy(label = "X"),
        Typeface.DEFAULT,
        16f,
        text.subSequence(start, end).toString(),
        RuntimeEnvironment.getApplication(),
      )
    text.setSpan(background, 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    text.setSpan(pill, start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    LinkPillSpan.prepareForMeasurement(text, 240)
    val layout =
      StaticLayout.Builder
        .obtain(text, 0, text.length, paint, 240)
        .setIncludePad(false)
        .build()
    val bitmap = Bitmap.createBitmap(240, 40, Bitmap.Config.ARGB_8888)
    background.drawBackground(Canvas(bitmap), paint, 0, 240, 0, 24, 40, text, 0, text.length, 0)
    val coveredLeft = layout.getPrimaryHorizontal(start)
    val coveredRight = layout.getPrimaryHorizontal(end)
    assertEquals(Color.TRANSPARENT, bitmap.getPixel(((coveredLeft + coveredRight) / 2).toInt(), 20))
    assertEquals(Color.RED, bitmap.getPixel((coveredLeft / 2).toInt(), 20))
    assertEquals(Color.RED, bitmap.getPixel(((coveredRight + layout.getLineWidth(0)) / 2).toInt(), 20))
  }

  @Test
  fun concealedSpoilerKeepsPartialPillCodeBackgroundHiddenUntilReveal() {
    val config = testStyleConfig(true, Color.RED)
    val originalText = "left original source path right"
    val text = SpannableString(originalText)
    val start = "left ".length
    val end = text.length - " right".length
    val background = CodeBackgroundSpan(config)
    val spoiler = SpoilerSpan(SpanStyleCache(config), BlockStyle(16f, "", "normal", Color.BLACK))
    val pill =
      LinkPillSpan(
        style.copy(label = "X"),
        Typeface.DEFAULT,
        16f,
        text.subSequence(start, end).toString(),
        RuntimeEnvironment.getApplication(),
      )
    text.setSpan(background, 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    text.setSpan(spoiler, 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    text.setSpan(pill, start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    LinkPillSpan.prepareForMeasurement(text, 240)
    val bitmap = Bitmap.createBitmap(240, 40, Bitmap.Config.ARGB_8888)
    background.drawBackground(Canvas(bitmap), paint, 0, 240, 0, 24, 40, text, 0, text.length, 0)
    assertTrue("Concealed code background must remain hidden around a pill", pixels(bitmap).all { it == Color.TRANSPARENT })

    spoiler.markRevealing()
    background.drawBackground(Canvas(bitmap), paint, 0, 240, 0, 24, 40, text, 0, text.length, 0)
    assertTrue("Code background outside the pill returns when reveal starts", pixels(bitmap).any { it == Color.RED })
    assertEquals(originalText, text.toString())
    assertSame(background, text.getSpans(0, text.length, CodeBackgroundSpan::class.java).single())
    assertEquals(0, text.getSpanStart(background))
    assertEquals(text.length, text.getSpanEnd(background))
  }

  private fun pixels(bitmap: Bitmap): IntArray =
    IntArray(bitmap.width * bitmap.height).also {
      bitmap.getPixels(it, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
    }

  private fun testStyleConfig(
    pill: Boolean,
    codeBackground: Int = Color.TRANSPARENT,
    presentationLabel: String = "Visual label",
  ): StyleConfig {
    val context = RuntimeEnvironment.getApplication()
    DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(context)

    fun inlineStyle() =
      JavaOnlyMap.of(
        "fontSize",
        16.0,
        "fontFamily",
        "",
        "fontWeight",
        "normal",
        "color",
        Color.BLACK.toDouble(),
        "marginTop",
        0.0,
        "marginBottom",
        0.0,
        "lineHeight",
        20.0,
        "underline",
        false,
        "backgroundColor",
        0.0,
        "borderColor",
        0.0,
      )
    val map = JavaOnlyMap()
    for (name in listOf("paragraph", "link", "strong", "em", "strikethrough", "code", "highlight")) {
      map.putMap(name, inlineStyle())
    }
    map.putMap(
      "code",
      inlineStyle().apply {
        putDouble("backgroundColor", codeBackground.toDouble())
        putDouble("borderColor", codeBackground.toDouble())
      },
    )
    for (name in listOf("superscript", "subscript")) {
      map.putMap(name, JavaOnlyMap.of("fontScale", 0.7, "baselineOffsetScale", 0.3))
    }
    map.putMap(
      "spoiler",
      JavaOnlyMap.of(
        "color",
        Color.GRAY.toDouble(),
        "particles",
        JavaOnlyMap.of("density", 1.0, "speed", 0.0),
        "solid",
        JavaOnlyMap.of("borderRadius", 4.0),
      ),
    )
    map.putMap(
      "taskList",
      JavaOnlyMap.of(
        "checkedColor",
        0.0,
        "borderColor",
        0.0,
        "checkboxSize",
        16.0,
        "checkboxBorderRadius",
        4.0,
        "checkmarkColor",
        0.0,
        "checkedTextColor",
        0.0,
        "checkedStrikethrough",
        false,
      ),
    )
    map.putArray(
      "linkVariants",
      JavaOnlyArray.of(
        JavaOnlyMap.of(
          "pattern",
          "^https:",
          "color",
          Color.BLUE.toDouble(),
          "underline",
          false,
          "backgroundColor",
          Color.LTGRAY.toDouble(),
          "pill",
          pill,
          "label",
          presentationLabel,
        ),
      ),
    )
    return StyleConfig(map, context, false, 0f)
  }

  @Test
  fun nestedBlockMarginsReduceAvailablePillWidth() {
    val text = SpannableString(original)
    val pill = span(style.copy(label = "A very long presentation label"))
    text.setSpan(pill, 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    text.setSpan(
      android.text.style.LeadingMarginSpan
        .Standard(25),
      0,
      text.length,
      Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
    )
    LinkPillSpan.prepareForMeasurement(text, 60)
    assertEquals(35, pill.getSize(paint, text, 0, text.length, null))
  }

  @Test
  fun widthChangesAreReportedForVisibleLayoutInvalidation() {
    val text = SpannableString(original)
    text.setSpan(span(), 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    assertTrue(LinkPillSpan.prepareForMeasurement(text, 40))
    assertFalse(LinkPillSpan.prepareForMeasurement(text, 40))
    assertTrue(LinkPillSpan.prepareForMeasurement(text, 80))
  }
}
