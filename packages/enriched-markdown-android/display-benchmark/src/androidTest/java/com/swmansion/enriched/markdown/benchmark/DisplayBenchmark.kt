@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.benchmark

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.RenderNode
import android.text.Spanned
import android.util.Log
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
import com.swmansion.enriched.markdown.EnrichedMarkdownInternalText
import com.swmansion.enriched.markdown.codehighlight.CodeHighlightPlugin
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.Md4cFlags
import com.swmansion.enriched.markdown.parser.Parser
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PluginSnapshot
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.styles.StyleConfig
import org.junit.Assume.assumeFalse
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
 *    vertical scroll container (spans, view construction, ...).
 * 2. The view is attached to a window-sized container, then measured and laid out.
 * 3. One draw is recorded into a [RenderNode], which is the UI-thread part of a real
 *    frame. RenderThread and GPU work are not included.
 *
 * Removing the view afterwards is not measured.
 *
 * [render], [layout] and [draw] split that same work into its phases, so a slow
 * document can be attributed to one of them. They share the fixture and the parsed
 * AST with [full] and keep per-iteration setup out of the measured region.
 *
 * The `code_medium` cases render one document three ways, so the cost code highlighting adds to
 * the render can be read off against the plain case: `_highlighted` with the plugin's token cache
 * warm, as on a re-render, and `_highlighted_cold` with every block tokenized afresh, as on a
 * document's first render.
 */
@RunWith(Parameterized::class)
class DisplayBenchmark(
  private val document: String,
) {
  @get:Rule val benchmarkRule = BenchmarkRule()

  @get:Rule val activityRule = ActivityScenarioRule(DisplayActivity::class.java)

  /** The fixture behind [document]: the highlighting cases share the plain case's. */
  private val fixture = document.substringBefore(HIGHLIGHTED_SUFFIX)

  private val plugins =
    if (HIGHLIGHTED_SUFFIX in document) PluginSnapshot.of(CodeHighlightPlugin) else PluginSnapshot.EMPTY

  /**
   * The plugin caches tokens process-wide by block, so a cold case renders a document whose blocks
   * no earlier iteration has seen; see [Harness.freshDocument].
   */
  private val cold = document.endsWith(COLD_SUFFIX)

  /**
   * Builds the view displaying [document] inside a vertical scroll container.
   *
   * `EnrichedMarkdown` has no entry point for a parsed document: it parses and renders
   * on a background thread and posts the result. This runs the same steps for a new
   * view synchronously, minus the parse: a fresh [Renderer] configured with the view's
   * style renders the AST to spans, which become the view's text.
   *
   * Setting the text directly skips the view's link movement method and its image and
   * table span registration; the documents contain no images or tables.
   */
  private fun createView(
    context: Context,
    document: MarkdownASTNode,
  ): View {
    val textView = EnrichedMarkdownInternalText(context).apply { setIsSelectable(false) }
    val renderer = newRenderer(context)
    textView.text = renderer.renderDocument(document)
    return scrollWrapped(context, textView)
  }

  /** The end-to-end path: build the view, attach it, measure, lay out and record one draw. */
  @Test
  fun full() {
    val harness = Harness()

    fun display(document: MarkdownASTNode = harness.parsed) {
      harness.container.addView(createView(harness.context, document))
      harness.layOutContainer()
      harness.recordDraw()
    }

    logSpanCount(harness.renderSpannable())

    harness.instrumentation.runOnMainSync {
      display()
      checkDisplayed(harness.container)
      harness.container.removeAllViews()
    }

    if (cold) {
      benchmarkRule.measureRepeatedOnMainThread {
        display(runWithMeasurementDisabled { harness.freshDocument() })
        runWithMeasurementDisabled { harness.container.removeAllViews() }
      }
    } else {
      benchmarkRule.measureRepeatedOnMainThread {
        display()
        runWithMeasurementDisabled { harness.container.removeAllViews() }
      }
    }
  }

  /** The AST to spannable buffer step alone: no view, no measure, no draw. */
  @Test
  fun render() {
    val harness = Harness()
    // Hoisted out of the measured region: the phase benchmarks measure the phase, and
    // building StyleConfig.default and a Renderer is not part of rendering spans.
    val renderer = newRenderer(harness.context)

    if (cold) {
      benchmarkRule.measureRepeatedOnMainThread {
        renderer.renderDocument(runWithMeasurementDisabled { harness.freshDocument() })
      }
    } else {
      benchmarkRule.measureRepeatedOnMainThread {
        renderer.renderDocument(harness.parsed)
      }
    }
  }

  /**
   * `setText` plus measure and layout on a freshly rendered spannable.
   *
   * Each iteration gets a fresh view, built with measurement disabled, because a
   * TextView that already holds the text has nothing left to lay out.
   *
   * It also gets a fresh buffer. The library hands the rendered buffer to the text
   * view uncopied (see `NoCopySpannableFactory`), so `setText` attaches the view's
   * change and selection watchers to that very instance as spans. Sharing one buffer
   * across iterations left the watchers of every discarded TextView on it, one more
   * per iteration, and every later `setSpan` and `getSpans` scanned the growing set:
   * `layout` drifted upwards until it exceeded `full` on the documents whose own span
   * count is too small to hide the accumulation. The renderer is hoisted so the
   * unmeasured setup is the render alone.
   */
  @Test
  fun layout() {
    // Tokenizing happens in the render alone; the warm case already covers the spans it leaves.
    assumeFalse(cold)
    val harness = Harness()
    val renderer = newRenderer(harness.context)

    benchmarkRule.measureRepeatedOnMainThread {
      val (textView, spannable) =
        runWithMeasurementDisabled {
          val view = newTextView(harness.context)
          harness.container.addView(scrollWrapped(harness.context, view))
          view to renderer.renderDocument(harness.parsed)
        }
      textView.text = spannable
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
    assumeFalse(cold)
    val harness = Harness()
    val spannable = harness.renderSpannable()

    harness.instrumentation.runOnMainSync {
      val textView = newTextView(harness.context).apply { text = spannable }
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

  /** A renderer with the default style and this case's [plugins]. */
  private fun newRenderer(context: Context): Renderer =
    Renderer().apply { configure(StyleConfig.default(context), context, plugins = plugins) }

  private fun newTextView(context: Context): EnrichedMarkdownInternalText =
    EnrichedMarkdownInternalText(context).apply { setIsSelectable(false) }

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
    val width: Int
    val height: Int

    private val widthSpec: Int
    private val heightSpec: Int
    private val renderNode: RenderNode

    private val markdown: String
    private var freshDocuments = 0

    init {
      markdown =
        instrumentation.context.assets
          .open("$fixture.md")
          .bufferedReader()
          .use { it.readText() }

      lateinit var hostContainer: FrameLayout
      activityRule.scenario.onActivity { hostContainer = it.container }
      instrumentation.waitForIdleSync()

      container = hostContainer
      context = container.context
      parsed = requireNotNull(Parser.shared.parseMarkdown(markdown, Md4cFlags(permissiveAutolinks = false)))
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
    fun renderSpannable(): CharSequence = newRenderer(context).renderDocument(parsed)

    /**
     * The fixture parsed again with a whitespace-only line after the first line of every fenced
     * block, spelled in spaces and tabs from a counter. Every call changes every block, so none hits
     * the plugin's token cache, while each block grows by the same few characters on every call. The
     * pattern repeats after 1024 calls, long after the cache has evicted its first entries. Parse
     * it with measurement disabled.
     */
    fun freshDocument(): MarkdownASTNode {
      val salt = freshDocuments++
      val line = String(CharArray(SALT_BITS) { bit -> if (salt shr bit and 1 == 1) '\t' else ' ' })
      val salted = markdown.replace(FENCE_OPENING) { "${it.value}$line\n" }
      return requireNotNull(Parser.shared.parseMarkdown(salted, Md4cFlags(permissiveAutolinks = false)))
    }
  }

  companion object {
    private const val LOG_TAG = "DisplayBenchmark"
    private const val HIGHLIGHTED_SUFFIX = "_highlighted"
    private const val COLD_SUFFIX = "_cold"
    private const val SALT_BITS = 10

    /** An opening fence that names a language, with the block's first line. */
    private val FENCE_OPENING = Regex("^```[a-z]+\\n.*\\n", RegexOption.MULTILINE)

    private val ALL_DOCUMENTS =
      listOf(
        "simple_small",
        "simple_medium",
        "simple_large",
        "complex_small",
        "complex_medium",
        "complex_large",
        "code_medium",
        "code_medium$HIGHLIGHTED_SUFFIX",
        "code_medium$HIGHLIGHTED_SUFFIX$COLD_SUFFIX",
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
