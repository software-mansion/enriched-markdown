package com.swmansion.enriched.markdown.benchmark

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.RenderNode
import android.text.Spanned
import android.util.Log
import android.util.TypedValue
import android.view.View
import android.view.View.MeasureSpec
import android.view.ViewGroup
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.FrameLayout
import android.widget.ScrollView
import androidx.benchmark.junit4.BenchmarkRule
import androidx.benchmark.junit4.measureRepeatedOnMainThread
import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.platform.app.InstrumentationRegistry
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.swmansion.enriched.markdown.EnrichedMarkdownInternalText
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.Md4cFlags
import com.swmansion.enriched.markdown.parser.Parser
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.styles.StyleConfig
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized
import java.io.File

/**
 * Time to display an already-parsed document on the first screen.
 *
 * The document is parsed once, outside the measurement. [full] then runs, per
 * iteration on the main thread:
 *
 * 1. [createView]: the library turns the parsed document into its view, inside a
 *    vertical scroll container (style, spans, view construction, ...).
 * 2. The view is attached to a window-sized container, then measured and laid out.
 * 3. One draw is recorded into a [RenderNode], which is the UI-thread part of a real
 *    frame. RenderThread and GPU work are not included.
 *
 * Removing the view afterwards is not measured.
 *
 * [render], [layout] and [draw] split that same work into its phases, so a slow
 * document can be attributed to one of them. They share the fixture and the parsed
 * AST with [full] and keep per-iteration setup out of the measured region.
 */
@RunWith(Parameterized::class)
class DisplayBenchmark(
  private val document: String,
) {
  @get:Rule val benchmarkRule = BenchmarkRule()

  @get:Rule val activityRule = ActivityScenarioRule(DisplayActivity::class.java)

  /**
   * Builds the view displaying [document] inside a vertical scroll container.
   *
   * Neither React Native view has an entry point for a parsed document: both parse and
   * render on a background thread and post the result. This runs the steps a text
   * segment of `EnrichedMarkdown` goes through synchronously, minus the parse: the
   * `markdownStyle` map becomes a [StyleConfig], a fresh [Renderer] configured with it
   * renders the AST to spans, and `applyStyledText` hands them to the view, as
   * `SegmentViewCreators.createTextView` does.
   *
   * It renders the whole document into that one view, as the commonmark flavor
   * does, rather than splitting it into segments. That skips the image span
   * registration; the documents contain no images or tables.
   */
  private fun createView(
    context: Context,
    styleMap: ReadableMap,
    document: MarkdownASTNode,
  ): View {
    val style = styleConfig(context, styleMap)
    val textView = newTextView(context, style)
    val renderer = Renderer().apply { configure(style, context) }
    textView.applyStyledText(renderer.renderDocument(document))
    return scrollWrapped(context, textView)
  }

  /** The end-to-end path: build the view, attach it, measure, lay out and record one draw. */
  @Test
  fun full() {
    val harness = Harness()

    fun display() {
      harness.container.addView(createView(harness.context, harness.styleMap, harness.parsed))
      harness.layOutContainer()
      harness.recordDraw()
    }

    logSpanCount(harness.renderSpannable())

    harness.instrumentation.runOnMainSync {
      display()
      checkDisplayed(harness.container)
      harness.container.removeAllViews()
    }

    benchmarkRule.measureRepeatedOnMainThread {
      display()
      runWithMeasurementDisabled { harness.container.removeAllViews() }
    }
  }

  /** The AST to spannable buffer step alone: no view, no measure, no draw. */
  @Test
  fun render() {
    val harness = Harness()
    // Hoisted out of the measured region: the phase benchmarks measure the phase, and
    // building the StyleConfig and a Renderer is not part of rendering spans.
    val renderer = Renderer().apply { configure(harness.style, harness.context) }

    benchmarkRule.measureRepeatedOnMainThread {
      renderer.renderDocument(harness.parsed)
    }
  }

  /**
   * `applyStyledText` plus measure and layout on a freshly rendered spannable.
   *
   * Each iteration gets a fresh view, built with measurement disabled, because a
   * TextView that already holds the text has nothing left to lay out.
   *
   * It also gets a fresh buffer. The library hands the rendered buffer to the text
   * view uncopied (see `NoCopySpannableFactory`), so `setText` attaches the view's
   * change and selection watchers to that very instance as spans. Sharing one buffer
   * across iterations would leave the watchers of every discarded TextView on it, one
   * more per iteration, and every later `setSpan` and `getSpans` would scan the growing
   * set: `layout` would drift upwards until it exceeded `full` on the documents whose
   * own span count is too small to hide the accumulation. The renderer is hoisted so
   * the unmeasured setup is the render alone.
   */
  @Test
  fun layout() {
    val harness = Harness()
    val renderer = Renderer().apply { configure(harness.style, harness.context) }

    benchmarkRule.measureRepeatedOnMainThread {
      val (textView, spannable) =
        runWithMeasurementDisabled {
          val view = newTextView(harness.context, harness.style)
          harness.container.addView(scrollWrapped(harness.context, view))
          view to renderer.renderDocument(harness.parsed)
        }
      textView.applyStyledText(spannable)
      harness.layOutContainer()
      runWithMeasurementDisabled { harness.container.removeAllViews() }
    }
  }

  /**
   * One recorded draw of a view that is already laid out.
   *
   * The tree is invalidated before each recording, with measurement disabled. Nothing
   * else dirties it between iterations, so without this the children still hold the
   * display lists recorded by the previous one: `drawChild` skips
   * `updateDisplayListIfDirty` and re-emits them as references, and the measured
   * region collapses to ~1us and zero allocations while recording nothing.
   */
  @Test
  fun draw() {
    val harness = Harness()
    val spannable = harness.renderSpannable()

    harness.instrumentation.runOnMainSync {
      val textView = newTextView(harness.context, harness.style).apply { applyStyledText(spannable) }
      harness.container.addView(scrollWrapped(harness.context, textView))
      harness.layOutContainer()
    }

    benchmarkRule.measureRepeatedOnMainThread {
      runWithMeasurementDisabled { harness.invalidateViewTree() }
      harness.recordDraw()
    }
  }

  /**
   * Fails if nothing visible was drawn, and saves the first screen as a PNG next to the
   * benchmark results so rendering can be compared by eye.
   */
  private fun checkDisplayed(container: FrameLayout) {
    val bitmap = Bitmap.createBitmap(container.width, container.height, Bitmap.Config.ARGB_8888)
    container.draw(Canvas(bitmap))

    val background = bitmap.getPixel(0, 0)
    var drawn = 0
    var sampled = 0
    for (y in 0 until bitmap.height step 4) {
      for (x in 0 until bitmap.width step 4) {
        sampled++
        if (bitmap.getPixel(x, y) != background) drawn++
      }
    }
    InstrumentationRegistry.getArguments().getString("additionalTestOutputDir")?.let { dir ->
      File(dir, "${javaClass.simpleName}_$document.png").outputStream().use {
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
      }
    }
    check(drawn > sampled / 200) { "Displaying $document drew almost nothing ($drawn of $sampled sampled pixels)" }
  }

  /**
   * Logs how many spans the renderer produced for [document]. Counted on the rendered
   * buffer before any view holds it, so the text view's own watchers are not included.
   */
  private fun logSpanCount(rendered: CharSequence) {
    val spans = (rendered as Spanned).getSpans(0, rendered.length, Any::class.java)
    Log.i(LOG_TAG, "$document: ${spans.size} spans")
  }

  /**
   * What `setMarkdownStyle` builds from the JS style map, with the JS defaults for the
   * font scaling props (`allowFontScaling` true, `maxFontSizeMultiplier` unset).
   */
  private fun styleConfig(
    context: Context,
    styleMap: ReadableMap,
  ): StyleConfig = StyleConfig(styleMap, context, allowFontScaling = true, maxFontSizeMultiplier = 0f)

  /** A text view configured as `SegmentViewCreators.createTextView` configures one. */
  private fun newTextView(
    context: Context,
    style: StyleConfig,
  ): EnrichedMarkdownInternalText =
    EnrichedMarkdownInternalText(context).apply {
      setIsSelectable(false)
      setTextSize(TypedValue.COMPLEX_UNIT_PX, style.paragraphStyle.fontSize)
    }

  private fun scrollWrapped(
    context: Context,
    textView: View,
  ): View = ScrollView(context).apply { addView(textView, MATCH_PARENT, WRAP_CONTENT) }

  /** The fixture, the parsed document and the window-sized container every benchmark shares. */
  private inner class Harness {
    val instrumentation = InstrumentationRegistry.getInstrumentation()
    val container: FrameLayout
    val context: Context
    val parsed: MarkdownASTNode

    /** The JS style map, which crosses the bridge before the view exists: never measured. */
    val styleMap: ReadableMap

    /** A [StyleConfig] for the phase benchmarks, which hoist building it. */
    val style: StyleConfig
    val width: Int
    val height: Int

    private val widthSpec: Int
    private val heightSpec: Int
    private val renderNode: RenderNode

    init {
      val markdown =
        instrumentation.context.assets
          .open("$document.md")
          .bufferedReader()
          .use { it.readText() }

      lateinit var hostContainer: FrameLayout
      activityRule.scenario.onActivity { hostContainer = it.container }
      instrumentation.waitForIdleSync()

      container = hostContainer
      context = container.context
      // StyleConfig converts dp and sp through PixelUtil, which reads the metrics a
      // React Native host initialises at startup. There is no host here.
      DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(context)
      styleMap = DefaultMarkdownStyle.load(instrumentation.context)
      style = styleConfig(context, styleMap)
      // The flags JS sends for the default commonmark flavor, except for permissive
      // autolinks, which are off to match the enriched-markdown-android benchmark.
      val flags = Md4cFlags(permissiveAutolinks = false, admonitions = false)
      parsed = requireNotNull(Parser.shared.parseMarkdown(markdown, flags, isGFM = false))
      width = container.width
      height = container.height
      check(width > 0 && height > 0) { "Container not laid out" }

      widthSpec = MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY)
      heightSpec = MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY)
      renderNode = RenderNode("display-benchmark").apply { setPosition(0, 0, width, height) }
    }

    fun layOutContainer() {
      container.measure(widthSpec, heightSpec)
      container.layout(container.left, container.top, container.left + width, container.top + height)
    }

    fun recordDraw() {
      val canvas = renderNode.beginRecording(width, height)
      try {
        container.draw(canvas)
      } finally {
        renderNode.endRecording()
      }
    }

    /**
     * Marks every view in [container] dirty so the next [recordDraw] re-records it.
     *
     * A recorded draw only re-runs the children whose display list is invalid, and
     * `View.invalidate` applies to one view, so the tree is walked by hand.
     */
    fun invalidateViewTree() {
      fun invalidate(view: View) {
        view.invalidate()
        if (view is ViewGroup) {
          for (index in 0 until view.childCount) invalidate(view.getChildAt(index))
        }
      }

      invalidate(container)
    }

    /** The spannable the draw phase starts from. Not measured. */
    fun renderSpannable(): CharSequence {
      val renderer = Renderer().apply { configure(style, context) }
      return renderer.renderDocument(parsed)
    }
  }

  companion object {
    private const val LOG_TAG = "DisplayBenchmark"

    private val ALL_DOCUMENTS =
      listOf(
        "simple_small",
        "simple_medium",
        "simple_large",
        "complex_small",
        "complex_medium",
        "complex_large",
      )

    /** All documents, or those listed in the `mdbench.documents` instrumentation argument. */
    @JvmStatic
    @Parameterized.Parameters(name = "{0}")
    fun documents(): List<String> {
      val requested =
        InstrumentationRegistry
          .getArguments()
          .getString("mdbench.documents")
          ?.split(',')
          ?.map { it.trim() }
          ?.filter { it.isNotEmpty() }
          ?: return ALL_DOCUMENTS
      val unknown = requested - ALL_DOCUMENTS.toSet()
      require(unknown.isEmpty()) { "Unknown documents: $unknown" }
      return ALL_DOCUMENTS.filter { it in requested }
    }
  }
}
