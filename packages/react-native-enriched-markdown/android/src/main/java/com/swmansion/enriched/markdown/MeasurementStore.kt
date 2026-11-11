package com.swmansion.enriched.markdown

import android.content.Context
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Build
import android.text.Layout
import android.text.Spannable
import android.text.Spanned
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils.TruncateAt
import android.util.Log
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.uimanager.PixelUtil
import com.facebook.yoga.YogaMeasureMode
import com.facebook.yoga.YogaMeasureOutput
import com.swmansion.enriched.markdown.parser.Md4cFlags
import com.swmansion.enriched.markdown.parser.Parser
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.segments.BlockSlotMeasurer
import com.swmansion.enriched.markdown.segments.BlockSlotSegmentView
import com.swmansion.enriched.markdown.segments.BlockquoteContainerView
import com.swmansion.enriched.markdown.segments.CodeBlockContainerView
import com.swmansion.enriched.markdown.segments.MarkdownSegmentRenderer
import com.swmansion.enriched.markdown.segments.RenderedSegment
import com.swmansion.enriched.markdown.segments.SegmentHeightMeasurer
import com.swmansion.enriched.markdown.segments.TableContainerView
import com.swmansion.enriched.markdown.segments.splitASTIntoSegments
import com.swmansion.enriched.markdown.spans.MarginBottomSpan
import com.swmansion.enriched.markdown.spans.MathMeasureRequest
import com.swmansion.enriched.markdown.spans.MathMetrics
import com.swmansion.enriched.markdown.spans.MathRenderMode
import com.swmansion.enriched.markdown.styles.LinkPillContent
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.common.BoundsForWidthUtils
import com.swmansion.enriched.markdown.utils.common.BreakStrategyUtils
import com.swmansion.enriched.markdown.utils.common.CodeBlockStreamingMode
import com.swmansion.enriched.markdown.utils.common.EllipsizeUtils
import com.swmansion.enriched.markdown.utils.common.FeatureFlags
import com.swmansion.enriched.markdown.utils.common.LinkRegexConfig
import com.swmansion.enriched.markdown.utils.common.MediaStreamingMode
import com.swmansion.enriched.markdown.utils.common.StreamingMarkdownFilter
import com.swmansion.enriched.markdown.utils.common.TableStreamingMode
import com.swmansion.enriched.markdown.utils.common.getArrayOrNull
import com.swmansion.enriched.markdown.utils.common.getBooleanOrDefault
import com.swmansion.enriched.markdown.utils.common.getIntOrDefault
import com.swmansion.enriched.markdown.utils.common.getMapOrNull
import com.swmansion.enriched.markdown.utils.common.getStringOrDefault
import com.swmansion.enriched.markdown.utils.common.parseImageRequestHeaders
import com.swmansion.enriched.markdown.utils.common.parseImageSources
import com.swmansion.enriched.markdown.utils.common.parseLinkPillContent
import com.swmansion.enriched.markdown.utils.common.parseLinkRecognition
import com.swmansion.enriched.markdown.utils.text.extensions.replaceMathSpansWithPlaceholders
import com.swmansion.enriched.markdown.utils.text.span.prepareWidthAwareSpans
import com.swmansion.enriched.markdown.utils.text.view.isAdoptedText
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.abs
import kotlin.math.ceil

/**
 * Manages text measurements for ShadowNode layout.
 * Parses and renders markdown to Spannable at measure time for accurate height calculation.
 */
object MeasurementStore {
  private const val TAG = "MeasurementStore"

  internal data class PaintParams(
    val typeface: Typeface,
    val fontSize: Float,
  )

  internal data class MeasurementParams(
    val cachedWidth: Float,
    val cachedSize: Long,
    val spannable: CharSequence?,
    val paintParams: PaintParams,
    val markdownHash: Int,
  )

  internal val data = ConcurrentHashMap<Int, MeasurementParams>()

  // Store font scaling settings per view ID
  private data class FontScalingSettings(
    val allowFontScaling: Boolean = true,
    val maxFontSizeMultiplier: Float = 0f,
  )

  private val fontScalingSettings = ConcurrentHashMap<Int, FontScalingSettings>()

  private val breakStrategies = ConcurrentHashMap<Int, String>()

  // The measure path and the display TextView resolve the same clamp. 0 means unlimited.
  private val numberOfLinesByViewId = ConcurrentHashMap<Int, Int>()

  private val ellipsizeModeByViewId = ConcurrentHashMap<Int, String>()

  // Code blocks the user wrapped, by document-order index across nesting (see CodeBlockWrapState).
  private val wrappedCodeBlocks = ConcurrentHashMap<Int, Set<Int>>()

  // The content size each view last laid its rendered markdown out at, and what each
  // view's last measurement saw: a stream's next update takes the first instead of
  // measuring the whole document again (laidOutSizeForStreamUpdate).
  private data class LaidOutSize(
    val widthPx: Float,
    val size: Long,
    val markdown: String,
  )

  private data class MeasuredInputs(
    val markdown: String,
    val layoutHash: Int,
    val widthPx: Float,
    // What the measurement returned, filled in once known.
    val size: Long? = null,
  )

  private val laidOutSizes = ConcurrentHashMap<Int, LaidOutSize>()

  // For each line of the text a view laid out itself at [widthPx], the widest line up to it
  // ([storeLaidOut]).
  private class LaidOutLines(
    val widthPx: Int,
    val widths: FloatArray,
  )

  private val laidOutLines = ConcurrentHashMap<Int, LaidOutLines>()
  private val previousInputs = ConcurrentHashMap<Int, MeasuredInputs>()

  private fun resolveFontScalingSettings(
    viewId: Int?,
    props: ReadableMap?,
  ): FontScalingSettings {
    val stored = viewId?.let { fontScalingSettings[it] }
    return FontScalingSettings(
      allowFontScaling =
        props?.takeIf { it.hasKey("allowFontScaling") }?.getBoolean("allowFontScaling")
          ?: stored?.allowFontScaling
          ?: true,
      maxFontSizeMultiplier =
        props?.takeIf { it.hasKey("maxFontSizeMultiplier") }?.getDouble("maxFontSizeMultiplier")?.toFloat()
          ?: stored?.maxFontSizeMultiplier
          ?: 0f,
    )
  }

  // TextView paints with ANTI_ALIAS_FLAG. On older Android a bare TextPaint lacks it, and the
  // glyph hinting that differs between the two moves text widths by a few pixels.
  private val measurePaint = TextPaint(Paint.ANTI_ALIAS_FLAG)
  private val measureRenderer = Renderer()

  // Measures a slot child through the GFM shadow node's current measure session
  // (BlockSlotMeasureSession); px in, px out, 0 outside a measurement.
  @JvmStatic
  private external fun nativeMeasureBlockSlot(
    slotId: String,
    x: Float,
    y: Float,
    width: Float,
  ): Float

  @JvmStatic
  private external fun nativeDiscardBlockSlotFrames()

  private val slotMeasurer =
    object : BlockSlotMeasurer {
      override fun measure(
        slotId: String,
        xPx: Float,
        yPx: Float,
        widthPx: Float,
      ) = nativeMeasureBlockSlot(slotId, xPx, yPx, widthPx)

      override fun discard() = nativeDiscardBlockSlotFrames()
    }

  @Volatile
  private var lastKnownFontScale: Float = 1.0f

  /** Updates measurement with rendered Spannable. Returns true if height changed. */
  fun store(
    id: Int,
    spannable: CharSequence?,
    paint: TextPaint,
    trailingMarginBottomPx: Float = 0f,
    renderedMarkdown: String = "",
  ): Boolean {
    val cached = data[id]
    val width = cached?.cachedWidth ?: 0f
    val oldSize = cached?.cachedSize ?: 0L
    val existingHash = cached?.markdownHash ?: 0
    val paintParams = PaintParams(paint.typeface ?: Typeface.DEFAULT, paint.textSize)

    var newSize = measure(width, spannable, paint, id)
    // A view's adopted buffer changes in place as patches land, on the main thread: a later
    // measurement at another width renders the markdown again instead of laying it out.
    val keptText = spannable.takeUnless { isAdoptedText(it) }
    if (trailingMarginBottomPx > 0f) {
      newSize =
        YogaMeasureOutput.make(
          YogaMeasureOutput.getWidth(newSize),
          YogaMeasureOutput.getHeight(newSize) + PixelUtil.toDIPFromPixel(trailingMarginBottomPx),
        )
    }
    data[id] = MeasurementParams(width, newSize, keptText, paintParams, existingHash)
    laidOutLines.remove(id)
    // Without the width the last measurement offered, the size isn't laid out for
    // it: the next measurement goes the full way and brings the width back.
    if (width > 0f) laidOutSizes[id] = LaidOutSize(width, newSize, renderedMarkdown) else laidOutSizes.remove(id)
    return oldSize != newSize
  }

  /**
   * [store] from the view's own [layout], which reflowed the text from [changedFrom] on: only
   * those lines are measured again. Null when [layout] isn't the one the measurement would build
   * (another width, or a line limit), and the caller stores in full.
   */
  fun storeLaidOut(
    id: Int,
    layout: Layout,
    changedFrom: Int,
    trailingMarginBottomPx: Float,
    renderedMarkdown: String,
  ): Boolean? {
    val cached = data[id] ?: return null
    val width = cached.cachedWidth
    if (width <= 0f || resolveMaxLines(id) > 0 || layout.width != ceil(width).toInt().coerceAtLeast(1)) return null

    val lineCount = layout.lineCount
    val previousWidths = laidOutLines[id]?.takeIf { it.widthPx == layout.width }?.widths
    val kept =
      if (previousWidths == null ||
        changedFrom <= 0
      ) {
        0
      } else {
        minOf(layout.getLineForOffset(changedFrom), previousWidths.size, lineCount)
      }
    val widths = FloatArray(lineCount)
    previousWidths?.copyInto(widths, 0, 0, kept)
    for (line in kept until lineCount) {
      widths[line] = maxOf(if (line > 0) widths[line - 1] else 0f, layout.getLineWidth(line))
    }
    laidOutLines[id] = LaidOutLines(layout.width, widths)

    val height = if (lineCount > 0) layout.getLineBottom(lineCount - 1).toFloat() else 0f
    val newSize =
      YogaMeasureOutput.make(
        PixelUtil.toDIPFromPixel(ceil(widths.lastOrNull() ?: 0f)),
        PixelUtil.toDIPFromPixel(height) + PixelUtil.toDIPFromPixel(trailingMarginBottomPx),
      )
    data[id] = cached.copy(cachedSize = newSize, spannable = null)
    laidOutSizes[id] = LaidOutSize(width, newSize, renderedMarkdown)
    return cached.cachedSize != newSize
  }

  /** The content size [id]'s view laid out [markdown] at, laid out for [widthPx]. */
  fun storeLaidOutSize(
    id: Int,
    widthPx: Float,
    size: Long,
    markdown: String,
  ) {
    laidOutSizes[id] = LaidOutSize(widthPx, size, markdown)
  }

  fun clearLaidOutSize(id: Int) {
    laidOutSizes.remove(id)
  }

  fun release(id: Int) {
    data.remove(id)
    laidOutSizes.remove(id)
    laidOutLines.remove(id)
    previousInputs.remove(id)
    numberOfLinesByViewId.remove(id)
    ellipsizeModeByViewId.remove(id)
    wrappedCodeBlocks.remove(id)
  }

  fun updateWrappedCodeBlocks(
    viewId: Int,
    indices: Set<Int>,
  ) {
    if (indices.isEmpty()) wrappedCodeBlocks.remove(viewId) else wrappedCodeBlocks[viewId] = indices
    data.remove(viewId)
  }

  fun invalidate(id: Int) {
    data.remove(id)
  }

  // Content-box width (px) the measure pass last wrapped at; the display view insets to match (#805).
  fun contentBoxWidthPx(id: Int): Float? = data[id]?.cachedWidth

  /** Main entry point for ShadowNode measurement. */
  fun getMeasureById(
    context: Context,
    id: Int?,
    width: Float,
    widthMode: YogaMeasureMode?,
    height: Float,
    heightMode: YogaMeasureMode?,
    props: ReadableMap?,
    splitTableSegments: Boolean = false,
    // The GFM host's slot children (see BlockSlotMeasureSession); each one is
    // measured where the walk places it.
    blockSlotIds: List<String> = emptyList(),
  ): Long {
    // Early exit for empty markdown. Honor widthMode here too: empty content has
    // zero intrinsic width, so only fill when the width is EXACTLY assigned -
    // otherwise an empty view would claim all available horizontal space.
    val markdown = props.getStringOrDefault("markdown", "")
    if (markdown.isEmpty()) {
      val emptyWidth = if (widthMode === YogaMeasureMode.EXACTLY) PixelUtil.toDIPFromPixel(width) else 0f
      return YogaMeasureOutput.make(emptyWidth, 0f)
    }

    // Resolve the line clamp from props here so the (background) measure pass and
    // the (main-thread) display TextView never race on the per-viewId cache. Only
    // overwrite when the key is present so we never clobber the view's value.
    if (id != null && props != null) {
      if (props.hasKey("numberOfLines")) {
        numberOfLinesByViewId[id] = props.getDouble("numberOfLines").toInt()
      }
      if (props.hasKey("ellipsizeMode")) {
        ellipsizeModeByViewId[id] = props.getString("ellipsizeMode") ?: EllipsizeUtils.DEFAULT_MODE
      }
    }

    val size = getMeasureByIdInternal(context, id, width, props, splitTableSegments, blockSlotIds)

    // Honor the Yoga width contract. When the parent assigns an exact width
    // (flex child, alignItems: stretch, explicit width / width: "100%"), fill it
    // instead of reporting the content's widest line, which would make the node
    // hug its content and wrap early. Mirrors RN's TextLayoutManager.calculateWidth;
    // iOS already does this via ENRMClampMeasuredSize.
    val resultWidth =
      if (widthMode === YogaMeasureMode.EXACTLY) {
        PixelUtil.toDIPFromPixel(width)
      } else {
        YogaMeasureOutput.getWidth(size)
      }

    var resultHeight = YogaMeasureOutput.getHeight(size)
    if (heightMode === YogaMeasureMode.AT_MOST) {
      resultHeight = resultHeight.coerceAtMost(PixelUtil.toDIPFromPixel(height))
    }

    return YogaMeasureOutput.make(resultWidth, resultHeight)
  }

  fun updateFontScalingSettings(
    viewId: Int,
    allowFontScaling: Boolean,
    maxFontSizeMultiplier: Float,
  ) {
    val previous = fontScalingSettings[viewId]
    fontScalingSettings[viewId] = FontScalingSettings(allowFontScaling, maxFontSizeMultiplier)
    if (previous != null && (previous.allowFontScaling != allowFontScaling || previous.maxFontSizeMultiplier != maxFontSizeMultiplier)) {
      data.remove(viewId)
    }
  }

  fun clearFontScalingSettings(viewId: Int) {
    fontScalingSettings.remove(viewId)
  }

  fun updateBreakStrategy(
    viewId: Int,
    strategy: String,
  ) {
    breakStrategies[viewId] = strategy
  }

  fun clearBreakStrategy(viewId: Int) {
    breakStrategies.remove(viewId)
  }

  private fun resolveBreakStrategy(viewId: Int?): Int = BreakStrategyUtils.resolveBreakStrategy(viewId?.let { breakStrategies[it] })

  fun updateNumberOfLines(
    viewId: Int,
    numberOfLines: Int,
  ) {
    numberOfLinesByViewId[viewId] = numberOfLines
  }

  fun updateEllipsizeMode(
    viewId: Int,
    mode: String,
  ) {
    ellipsizeModeByViewId[viewId] = mode
  }

  private fun resolveMaxLines(viewId: Int?): Int = viewId?.let { numberOfLinesByViewId[it] } ?: 0

  private fun resolveEllipsize(viewId: Int?): TruncateAt? =
    EllipsizeUtils.resolveTruncateAt(viewId?.let { ellipsizeModeByViewId[it] } ?: EllipsizeUtils.DEFAULT_MODE)

  private fun getMeasureByIdInternal(
    context: Context,
    id: Int?,
    width: Float,
    props: ReadableMap?,
    splitTableSegments: Boolean,
    blockSlotIds: List<String>,
  ): Long {
    val (allowFontScaling, maxFontSizeMultiplier) = resolveFontScalingSettings(id, props)

    val fontScale = checkAndUpdateFontScale(context, allowFontScaling, maxFontSizeMultiplier)

    if (id == null || blockSlotIds.isNotEmpty()) {
      // Slot children are measured where the walk places them; nothing here takes the view's size.
      if (id != null) previousInputs.remove(id)
      val full =
        measureInFull(context, id, width, props, splitTableSegments, blockSlotIds, allowFontScaling, fontScale, maxFontSizeMultiplier)
      return revealedSize(id, width, props, full) ?: full
    }
    laidOutSizeForStreamUpdate(id, width, props, splitTableSegments, allowFontScaling, fontScale, maxFontSizeMultiplier)
      ?.let { return it }
    return measureInFull(context, id, width, props, splitTableSegments, blockSlotIds, allowFontScaling, fontScale, maxFontSizeMultiplier)
      .also { recordMeasured(id, it) }
  }

  // With smooth pacing the view shows only a start of the markdown, the slots' blocks arriving with
  // the words: the height it laid that start out at. The whole document still places every slot, so a
  // block's space is reserved as soon as it is revealed (the shadow node hides the slots below).
  private fun revealedSize(
    id: Int?,
    width: Float,
    props: ReadableMap?,
    full: Long,
  ): Long? {
    if (id == null || !smooth(props)) return null
    val markdown = props.getStringOrDefault("markdown", "")
    val laidOut =
      laidOutSizes[id]?.takeIf {
        abs(it.widthPx - width) < 1f && it.markdown.length < markdown.length && markdownExtends(it.markdown, markdown)
      } ?: return null
    val height = YogaMeasureOutput.getHeight(laidOut.size)
    return if (height < YogaMeasureOutput.getHeight(full)) YogaMeasureOutput.make(YogaMeasureOutput.getWidth(full), height) else null
  }

  private fun smooth(props: ReadableMap?): Boolean = props?.getMapOrNull("streamingConfig")?.getBooleanOrDefault("smooth", false) == true

  private fun measureInFull(
    context: Context,
    id: Int?,
    width: Float,
    props: ReadableMap?,
    splitTableSegments: Boolean,
    blockSlotIds: List<String>,
    allowFontScaling: Boolean,
    fontScale: Float,
    maxFontSizeMultiplier: Float,
  ): Long {
    // Split measurement always goes through the full measure path (no spannable caching)
    if (splitTableSegments) {
      return measureAndCacheSplit(context, id, width, props, allowFontScaling, fontScale, maxFontSizeMultiplier, blockSlotIds)
    }

    val safeId = id ?: return measureAndCache(context, null, width, props, allowFontScaling, fontScale, maxFontSizeMultiplier)
    val cached = data[safeId] ?: return measureAndCache(context, safeId, width, props, allowFontScaling, fontScale, maxFontSizeMultiplier)

    val currentHash = computePropsHash(props, allowFontScaling, fontScale, maxFontSizeMultiplier)

    if (cached.markdownHash != currentHash) {
      return measureAndCache(context, safeId, width, props, allowFontScaling, fontScale, maxFontSizeMultiplier)
    }

    // Width changed - re-measure with cached spannable
    if (cached.cachedWidth != width) {
      val spannable =
        cached.spannable ?: return measureAndCache(context, safeId, width, props, allowFontScaling, fontScale, maxFontSizeMultiplier)
      val newSize = measure(width, spannable, cached.paintParams, safeId)
      data[safeId] = cached.copy(cachedWidth = width, cachedSize = newSize)
      return newSize
    }

    return cached.cachedSize
  }

  // A stream's update: the markdown only grew and nothing else that sizes the content
  // changed. The view lays out every render it applies and asks for a new layout when
  // its height changes, so the size it laid out at is behind by at most the render in
  // flight; taking it spares rendering and measuring the whole document again on every
  // update. The same document at the same width gets the previous answer back; new
  // content, another width or a view that hasn't laid anything out yet measure in full.
  internal fun laidOutSizeForStreamUpdate(
    id: Int,
    width: Float,
    props: ReadableMap?,
    splitTableSegments: Boolean,
    allowFontScaling: Boolean,
    fontScale: Float,
    maxFontSizeMultiplier: Float,
  ): Long? {
    val markdown = props.getStringOrDefault("markdown", "")
    var layoutHash = computePropsHashForMarkdown("", props, allowFontScaling, fontScale, maxFontSizeMultiplier)
    layoutHash = 31 * layoutHash + props.getBooleanOrDefault("isGFM", false).hashCode()
    layoutHash = 31 * layoutHash + props.getBooleanOrDefault("streaming", false).hashCode()
    // Only the modes change what is laid out; the animation, its options and pacing do not.
    val streamingConfig = props.getMapOrNull("streamingConfig")
    layoutHash = 31 * layoutHash + streamingConfig.getStringOrDefault("tableMode", "").hashCode()
    layoutHash = 31 * layoutHash + streamingConfig.getStringOrDefault("codeBlockMode", "").hashCode()
    layoutHash = 31 * layoutHash + streamingConfig.getStringOrDefault("mediaMode", "").hashCode()
    layoutHash = 31 * layoutHash + splitTableSegments.hashCode()
    layoutHash = 31 * layoutHash + (wrappedCodeBlocks[id]?.hashCode() ?: 0)
    layoutHash = 31 * layoutHash + (breakStrategies[id]?.hashCode() ?: 0)

    val previous = previousInputs.put(id, MeasuredInputs(markdown, layoutHash, width)) ?: return null
    // The view's size counts for an earlier state of this stream, not a document it replaced.
    val laidOut = laidOutSizes[id]?.takeIf { abs(it.widthPx - width) < 1f && markdownExtends(it.markdown, markdown) }
    val size =
      when (
        chooseMeasurement(
          streamUpdate = previous.layoutHash == layoutHash && markdownExtends(previous.markdown, markdown),
          grew = markdown.length > previous.markdown.length,
          viewLaidOutAgain = laidOut != null && (laidOut.markdown == markdown || (smooth(props) && laidOut.size != previous.size)),
          hasLaidOutSize = laidOut != null,
          samePreviousWidth = previous.size != null && previous.widthPx == width,
        )
      ) {
        MeasurementSource.LAID_OUT -> laidOut?.size
        MeasurementSource.PREVIOUS -> previous.size
        MeasurementSource.FULL -> null
      } ?: return null
    recordMeasured(id, size)
    return size
  }

  internal enum class MeasurementSource { FULL, PREVIOUS, LAID_OUT }

  /**
   * Picks the source of a measurement, as iOS's ENRMChooseMeasurement does. Android's
   * measurement can't see the view's height counter, so the view having laid out this
   * document, or with smooth pacing (it renders part of it) a size other than the last
   * answer, stands in for the view asking again, and a grown document never takes the previous
   * answer: a view sized to its content would keep it for good.
   */
  internal fun chooseMeasurement(
    streamUpdate: Boolean,
    grew: Boolean,
    viewLaidOutAgain: Boolean,
    hasLaidOutSize: Boolean,
    samePreviousWidth: Boolean,
  ): MeasurementSource =
    when {
      !streamUpdate -> MeasurementSource.FULL
      hasLaidOutSize && (grew || viewLaidOutAgain) -> MeasurementSource.LAID_OUT
      !grew && samePreviousWidth -> MeasurementSource.PREVIOUS
      else -> MeasurementSource.FULL
    }

  // Remembers what the measurement of [id] returned, for the next one to compare with.
  internal fun recordMeasured(
    id: Int,
    size: Long,
  ) {
    previousInputs.computeIfPresent(id) { _, inputs -> inputs.copy(size = size) }
  }

  /** Whether [current] keeps all of [previous] and only adds to it, as every update of a stream does. */
  internal fun markdownExtends(
    previous: String,
    current: String,
  ): Boolean = previous.isNotEmpty() && current.startsWith(previous)

  private fun md4cFlagsFromProps(props: ReadableMap?): Md4cFlags {
    val flags = props.getMapOrNull("md4cFlags")
    return Md4cFlags(
      underline = flags.getBooleanOrDefault("underline", false),
      latexMath = FeatureFlags.IS_MATH_ENABLED && flags.getBooleanOrDefault("latexMath", true),
      superscript = flags.getBooleanOrDefault("superscript", false),
      subscript = flags.getBooleanOrDefault("subscript", false),
      strikethrough = flags.getBooleanOrDefault("strikethrough", false),
      highlight = flags.getBooleanOrDefault("highlight", false),
      hardSoftBreaks = flags.getBooleanOrDefault("hardSoftBreaks", false),
      preserveBlankLines = flags.getBooleanOrDefault("preserveBlankLines", false),
      admonitions = flags.getBooleanOrDefault("admonitions", true),
    )
  }

  private fun computePropsHash(
    props: ReadableMap?,
    allowFontScaling: Boolean,
    fontScale: Float,
    maxFontSizeMultiplier: Float,
  ): Int {
    val markdown = renderableMarkdownFromProps(props, md4cFlagsFromProps(props))
    return computePropsHashForMarkdown(markdown, props, allowFontScaling, fontScale, maxFontSizeMultiplier)
  }

  // The props' markdown as the view renders it: while streaming, the core streaming
  // session's snapshot. The modes come with the props (conversions.h), so the first
  // measurement and one after a mode change prepare exactly what the view renders.
  private fun renderableMarkdownFromProps(
    props: ReadableMap?,
    md4cFlags: Md4cFlags,
  ): String {
    val markdown = props.getStringOrDefault("markdown", "")
    if (!props.getBooleanOrDefault("streaming", false)) return markdown
    val streamingConfig = props.getMapOrNull("streamingConfig")
    return StreamingMarkdownFilter
      .renderableMarkdownForStreaming(
        markdown,
        md4cFlags,
        TableStreamingMode.fromString(streamingConfig.getStringOrDefault("tableMode", "")),
        CodeBlockStreamingMode.fromString(streamingConfig.getStringOrDefault("codeBlockMode", "")),
        MediaStreamingMode.fromString(streamingConfig.getStringOrDefault("mediaMode", "")),
      ).markdown
  }

  private fun computePropsHashForMarkdown(
    markdown: String,
    props: ReadableMap?,
    allowFontScaling: Boolean,
    fontScale: Float,
    maxFontSizeMultiplier: Float,
  ): Int {
    val styleMap = props.getMapOrNull("markdownStyle")
    val md4cFlagsMap = props.getMapOrNull("md4cFlags")
    val allowTrailingMargin = props.getBooleanOrDefault("allowTrailingMargin", false)
    val imageRequestHeaders = parseImageRequestHeaders(props.getArrayOrNull("imageRequestHeaders"))
    val imageSources = parseImageSources(props.getArrayOrNull("imageSources"))
    val linkPillContent = parseLinkPillContent(props.getArrayOrNull("linkPillContent"))
    var result = markdown.hashCode()
    // Hashed as plain maps: a native array inside (the style's `linkVariants`) hashes by
    // identity, so the same style would hash differently on every measurement.
    result = 31 * result + (styleMap?.toHashMap()?.hashCode() ?: 0)
    result = 31 * result + (md4cFlagsMap?.toHashMap()?.hashCode() ?: 0)
    result = 31 * result + parseLinkRecognition(props.getMapOrNull("linkRecognition")).hashCode()
    result = 31 * result + fontScale.toBits()
    result = 31 * result + allowFontScaling.hashCode()
    result = 31 * result + maxFontSizeMultiplier.toBits()
    result = 31 * result + allowTrailingMargin.hashCode()
    result = 31 * result + imageRequestHeaders.hashCode()
    result = 31 * result + imageSources.hashCode()
    result = 31 * result + linkPillContent.hashCode()
    result = 31 * result + props.getIntOrDefault("numberOfLines", 0)
    result = 31 * result + props.getStringOrDefault("ellipsizeMode", EllipsizeUtils.DEFAULT_MODE).hashCode()
    return result
  }

  private fun checkAndUpdateFontScale(
    context: Context,
    allowFontScaling: Boolean,
    maxFontSizeMultiplier: Float,
  ): Float {
    if (!allowFontScaling) {
      // Clear cache if we switched from scaling to non-scaling
      if (lastKnownFontScale != 1.0f) {
        lastKnownFontScale = 1.0f
        data.clear()
      }
      return 1.0f
    }

    var currentFontScale = context.resources.configuration.fontScale

    if (maxFontSizeMultiplier >= 1.0f && currentFontScale > maxFontSizeMultiplier) {
      currentFontScale = maxFontSizeMultiplier
    }
    if (currentFontScale != lastKnownFontScale) {
      lastKnownFontScale = currentFontScale
      data.clear()
    }
    return currentFontScale
  }

  private fun measureAndCache(
    context: Context,
    id: Int?,
    width: Float,
    props: ReadableMap?,
    allowFontScaling: Boolean,
    fontScale: Float,
    maxFontSizeMultiplier: Float,
  ): Long {
    // 1. Extract Props & Setup
    val styleMap = props.getMapOrNull("markdownStyle")
    val md4cFlags = md4cFlagsFromProps(props)
    val markdown = renderableMarkdownFromProps(props, md4cFlags)
    val isGFM = props.getBooleanOrDefault("isGFM", false)

    val fontSize = getInitialFontSize(styleMap, context, allowFontScaling, fontScale, maxFontSizeMultiplier)
    val propsHash = computePropsHash(props, allowFontScaling, fontScale, maxFontSizeMultiplier)

    // 2. Render & Measure
    measurePaint.textSize = fontSize
    val imageRequestHeaders = parseImageRequestHeaders(props.getArrayOrNull("imageRequestHeaders"))
    val linkRecognition = parseLinkRecognition(props.getMapOrNull("linkRecognition"))
    val spannable =
      tryRenderMarkdown(
        markdown,
        styleMap,
        context,
        md4cFlags,
        isGFM,
        allowFontScaling,
        maxFontSizeMultiplier,
        imageRequestHeaders,
        parseLinkPillContent(props.getArrayOrNull("linkPillContent")),
        linkRecognition.text,
        linkRecognition.inlineCode,
      )
    spannable?.replaceMathSpansWithPlaceholders(context)
    val textToMeasure = spannable ?: markdown
    val (size, _) = measureWithLayout(width, textToMeasure, measurePaint, id)

    // 3. Calculate Margin
    val allowTrailingMargin = props.getBooleanOrDefault("allowTrailingMargin", false)
    val marginBottom =
      if (allowTrailingMargin && spannable != null) {
        PixelUtil.toDIPFromPixel(measureRenderer.getLastElementMarginBottom())
      } else {
        0f
      }

    // 4. Finalize Height
    val currentWidth = YogaMeasureOutput.getWidth(size)
    val currentHeight = YogaMeasureOutput.getHeight(size)
    val adjustedSize = YogaMeasureOutput.make(currentWidth, currentHeight + marginBottom)

    if (id != null) {
      data[id] = MeasurementParams(width, adjustedSize, textToMeasure, PaintParams(Typeface.DEFAULT, fontSize), propsHash)
    }

    return adjustedSize
  }

  private fun measureAndCacheSplit(
    context: Context,
    id: Int?,
    width: Float,
    props: ReadableMap?,
    allowFontScaling: Boolean,
    fontScale: Float,
    maxFontSizeMultiplier: Float,
    blockSlotIds: List<String>,
  ): Long {
    val isStreaming = props.getBooleanOrDefault("streaming", false)
    val md4cFlags = md4cFlagsFromProps(props)
    val markdown = renderableMarkdownFromProps(props, md4cFlags)
    val wrapped =
      if (props.getBooleanOrDefault("enableCodeBlockWrapToggle", true)) {
        id?.let { wrappedCodeBlocks[it] } ?: emptySet()
      } else {
        emptySet()
      }
    // A Set's hashCode sums its elements, so {} and {0} would collide; the sorted list's doesn't.
    // Density joins the key: an app that handles density changes itself keeps the view
    // alive while every px measurement below changes. So do the slot ids: a size
    // measured with React children in place must not serve the slot-free document.
    val density = context.resources.displayMetrics.density
    val propsHash =
      31 * (
        31 * (
          31 * computePropsHashForMarkdown(markdown, props, allowFontScaling, fontScale, maxFontSizeMultiplier) +
            wrapped.sorted().hashCode()
        ) + density.hashCode()
      ) + blockSlotIds.hashCode()

    // Streaming shortcut: reuse cached size when the prepared content and
    // width are unchanged. When it changes (e.g. a table becomes complete),
    // the hash differs and we fall through to full measure.
    // Slot children need their frames recorded on every measure, so they never
    // take it.
    if (isStreaming && id != null && blockSlotIds.isEmpty()) {
      val cached = data[id]
      if (cached != null && cached.cachedWidth == width && cached.markdownHash == propsHash) {
        return cached.cachedSize
      }
    }
    val styleMap =
      props.getMapOrNull("markdownStyle")
        ?: return YogaMeasureOutput.make(PixelUtil.toDIPFromPixel(width), 0f)

    val isGFM = props.getBooleanOrDefault("isGFM", true)
    val allowTrailingMargin = props.getBooleanOrDefault("allowTrailingMargin", false)
    val fontSize = getInitialFontSize(styleMap, context, allowFontScaling, fontScale, maxFontSizeMultiplier)

    val linkRecognition = parseLinkRecognition(props.getMapOrNull("linkRecognition"))
    val imageSources = parseImageSources(props.getArrayOrNull("imageSources"))

    return try {
      val ast =
        Parser.shared.parseMarkdown(
          markdown,
          md4cFlags,
          isGFM,
          linkRecognition.text,
          linkRecognition.inlineCode,
          blockSlotIds.toSet(),
          imageSources.isNotEmpty(),
        )
          ?: return YogaMeasureOutput.make(PixelUtil.toDIPFromPixel(width), 0f)

      val style = StyleConfig(styleMap, context, allowFontScaling, maxFontSizeMultiplier)
      style.imageRequestHeaders = parseImageRequestHeaders(props.getArrayOrNull("imageRequestHeaders"))
      style.imageSourceOverrides = imageSources
      style.linkPillContent = parseLinkPillContent(props.getArrayOrNull("linkPillContent"))
      val segments = splitASTIntoSegments(ast)
      val renderedSegments = MarkdownSegmentRenderer.render(segments, style, context, null, null)

      val mathHeightByIndex = HashMap<Int, Float>()
      val mathSegmentIndices = mutableListOf<Int>()
      val mathRequests = mutableListOf<MathMeasureRequest>()
      for ((i, segment) in renderedSegments.withIndex()) {
        if (segment is RenderedSegment.Math) {
          mathSegmentIndices.add(i)
          mathRequests.add(
            MathMeasureRequest(
              fontSize = style.mathStyle.fontSize,
              latex = segment.latex,
              mode = MathRenderMode.Display,
            ),
          )
        }
      }
      if (mathRequests.isNotEmpty()) {
        val mathResults = measureMathOnMainThread(context, mathRequests)
        for (i in mathSegmentIndices.indices) {
          val metrics = mathResults[i]
          mathHeightByIndex[mathSegmentIndices[i]] =
            ceil(metrics.ascent + metrics.descent).toInt() + (style.mathStyle.padding * 2)
        }
      }

      // One walk for the root stack and for nested quotes (SegmentHeightMeasurer),
      // so measure and render cannot drift between the two.
      val stack =
        SegmentHeightMeasurer.measureRootStack(
          renderedSegments,
          style,
          context,
          width,
          fontSize,
          resolveBreakStrategy(id),
          allowTrailingMargin,
          mathHeightForIndex = { mathHeightByIndex[it] ?: 0f },
          wrapCursor = CodeBlockWrapCursor(wrapped),
          slotMeasurer = slotMeasurer,
        )
      val totalHeightPx = stack.heightPx
      val maxContentWidthPx = stack.maxContentWidthPx

      val totalHeightDip = PixelUtil.toDIPFromPixel(totalHeightPx)
      val measuredWidthDip = PixelUtil.toDIPFromPixel(maxContentWidthPx).coerceAtMost(PixelUtil.toDIPFromPixel(width))
      val result = YogaMeasureOutput.make(measuredWidthDip, totalHeightDip)

      if (id != null) {
        data[id] = MeasurementParams(width, result, null, PaintParams(Typeface.DEFAULT, fontSize), propsHash)
      }
      result
    } catch (e: Exception) {
      // The fallback measures without slots, so every block renders natively.
      slotMeasurer.discard()
      Log.w(TAG, "Split measurement failed, falling back without block renderers", e)
      measureAndCache(context, id, width, props, allowFontScaling, fontScale, maxFontSizeMultiplier)
    }
  }

  private fun createStaticLayout(
    text: CharSequence,
    fontSize: Float,
    widthPx: Int,
    viewId: Int?,
  ): StaticLayout {
    measurePaint.textSize = fontSize
    prepareWidthAwareSpans(text, widthPx)
    return StaticLayout.Builder
      .obtain(text, 0, text.length, measurePaint, widthPx)
      .setIncludePad(false)
      .setLineSpacing(0f, 1f)
      .apply {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
          @Suppress("WrongConstant")
          setBreakStrategy(resolveBreakStrategy(viewId))
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
          setUseLineSpacingFromFallbacks(true)
        }
      }.build()
  }

  private fun tryRenderMarkdown(
    markdown: String,
    styleMap: ReadableMap?,
    context: Context,
    md4cFlags: Md4cFlags,
    isGFM: Boolean,
    allowFontScaling: Boolean,
    maxFontSizeMultiplier: Float,
    imageRequestHeaders: Map<String, String> = emptyMap(),
    linkPillContent: Map<String, LinkPillContent> = emptyMap(),
    linkRegex: LinkRegexConfig? = null,
    inlineCodeLinkRegex: LinkRegexConfig? = null,
  ): Spannable? {
    if (styleMap == null) return null

    return try {
      val ast = Parser.shared.parseMarkdown(markdown, md4cFlags, isGFM, linkRegex, inlineCodeLinkRegex) ?: return null
      val style = StyleConfig(styleMap, context, allowFontScaling, maxFontSizeMultiplier)
      style.imageRequestHeaders = imageRequestHeaders
      style.linkPillContent = linkPillContent
      measureRenderer.configure(style, context)
      measureRenderer.renderDocument(ast, null)
    } catch (e: Exception) {
      Log.w(TAG, "Failed to render markdown for measurement, falling back to raw text", e)
      null
    }
  }

  private fun getInitialFontSize(
    styleMap: ReadableMap?,
    context: Context,
    allowFontScaling: Boolean,
    fontScale: Float,
    maxFontSizeMultiplier: Float,
  ): Float {
    val fontSizeSp = styleMap?.getMap("paragraph")?.getDouble("fontSize")?.toFloat() ?: 16f
    val density = context.resources.displayMetrics.density

    if (!allowFontScaling) {
      return ceil(fontSizeSp * density)
    }

    val cappedFontScale =
      if (maxFontSizeMultiplier >= 1.0f && fontScale > maxFontSizeMultiplier) {
        maxFontSizeMultiplier
      } else {
        fontScale
      }
    return ceil(fontSizeSp * cappedFontScale * density)
  }

  private fun measure(
    maxWidth: Float,
    text: CharSequence?,
    paintParams: PaintParams,
    viewId: Int?,
  ): Long {
    measurePaint.reset()
    measurePaint.isAntiAlias = true
    measurePaint.typeface = paintParams.typeface
    measurePaint.textSize = paintParams.fontSize
    return measure(maxWidth, text, measurePaint, viewId)
  }

  private fun measure(
    maxWidth: Float,
    text: CharSequence?,
    paint: TextPaint,
    viewId: Int?,
  ): Long {
    val content = text ?: ""
    val safeWidth = ceil(maxWidth).toInt().coerceAtLeast(1)
    prepareWidthAwareSpans(content, safeWidth)

    val layout = buildMeasureLayout(content, paint, safeWidth, viewId)
    val visibleLineCount = visibleLineCount(layout, viewId)
    val measuredHeight = truncatedHeight(layout, visibleLineCount, content)

    // Calculate actual content width (widest visible line)
    val measuredWidth = (0 until visibleLineCount).maxOfOrNull { layout.getLineWidth(it) } ?: 0f

    return YogaMeasureOutput.make(
      PixelUtil.toDIPFromPixel(ceil(measuredWidth)),
      PixelUtil.toDIPFromPixel(measuredHeight),
    )
  }

  private fun buildMeasureLayout(
    content: CharSequence,
    paint: TextPaint,
    widthPx: Int,
    viewId: Int?,
  ): StaticLayout {
    val builder =
      StaticLayout.Builder
        .obtain(content, 0, content.length, paint, widthPx)
        .setIncludePad(false)
        .setLineSpacing(0f, 1f)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      @Suppress("WrongConstant")
      builder.setBreakStrategy(resolveBreakStrategy(viewId))
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      builder.setUseLineSpacingFromFallbacks(true)
    }

    BoundsForWidthUtils.applyTo(builder)
    applyLineLimit(builder, viewId)
    return builder.build()
  }

  // Applies the per-view numberOfLines / ellipsizeMode clamp to a builder, matching
  // RN's TextLayoutManager.buildLayout: only when a line limit is set.
  private fun applyLineLimit(
    builder: StaticLayout.Builder,
    viewId: Int?,
  ) {
    val maxLines = resolveMaxLines(viewId)
    if (maxLines > 0) {
      builder.setMaxLines(maxLines).setEllipsize(resolveEllipsize(viewId))
    }
  }

  private fun visibleLineCount(
    layout: StaticLayout,
    viewId: Int?,
  ): Int {
    val maxLines = resolveMaxLines(viewId)
    return if (maxLines > 0) minOf(maxLines, layout.lineCount) else layout.lineCount
  }

  private fun truncatedHeight(
    layout: StaticLayout,
    visibleLineCount: Int,
    text: CharSequence,
  ): Float {
    if (visibleLineCount <= 0) return 0f
    val lastLine = visibleLineCount - 1
    val bottom = layout.getLineBottom(lastLine).toFloat()
    return (bottom - measureLeakedTrailingMargin(layout, lastLine, text)).coerceAtLeast(0f)
  }

  // When we clamp the text mid-paragraph, drop the trailing block margin that Android
  // bakes into the truncated last line (only when content follows, like MarginBottomSpan).
  private fun measureLeakedTrailingMargin(
    layout: StaticLayout,
    lastLine: Int,
    text: CharSequence,
  ): Float {
    val spanned = text as? Spanned ?: return 0f
    val lineStart = layout.getLineStart(lastLine)
    val lineEnd = layout.getLineEnd(lastLine)
    if (lineEnd <= lineStart || lineEnd < 1 || text[lineEnd - 1] != '\n') return 0f
    if (!hasContentAfter(text, lineEnd)) return 0f
    val trailing =
      spanned
        .getSpans(lineStart, lineEnd, MarginBottomSpan::class.java)
        .firstOrNull { spanned.getSpanEnd(it) == lineEnd } ?: return 0f
    return trailing.marginBottom.toInt().toFloat()
  }

  private fun hasContentAfter(
    text: CharSequence,
    pos: Int,
  ): Boolean {
    if (pos >= text.length) return false
    if (text[pos] == '\n') {
      val nextPos = pos + 1
      if (nextPos >= text.length) return false
      return text[nextPos] != '\n'
    }
    return true
  }

  /**
   * Measures text and returns both the size and the layout for calculating last line descent.
   */
  private fun measureWithLayout(
    maxWidth: Float,
    text: CharSequence?,
    paint: TextPaint,
    viewId: Int?,
  ): Pair<Long, StaticLayout> {
    val content = text ?: ""
    val widthPx = ceil(maxWidth).toInt().coerceAtLeast(1)
    prepareWidthAwareSpans(content, widthPx)

    val layout = buildMeasureLayout(content, paint, widthPx, viewId)

    val visibleLineCount = visibleLineCount(layout, viewId)

    // Find the widest visible line to get the actual content width
    val maxLineWidth =
      (0 until visibleLineCount)
        .maxOfOrNull { layout.getLineWidth(it) } ?: 0f

    val size =
      YogaMeasureOutput.make(
        PixelUtil.toDIPFromPixel(ceil(maxLineWidth)),
        PixelUtil.toDIPFromPixel(truncatedHeight(layout, visibleLineCount, content)),
      )

    return size to layout
  }

  private fun measureMathOnMainThread(
    context: Context,
    requests: List<MathMeasureRequest>,
  ): List<MathMetrics> {
    if (!FeatureFlags.IS_MATH_ENABLED || requests.isEmpty()) {
      return requests.map { estimateMathFallback(it) }
    }
    return try {
      val mathMeasureHelperClass = Class.forName("com.swmansion.enriched.markdown.spans.MathMeasureHelper")
      val method = mathMeasureHelperClass.getMethod("measure", Context::class.java, List::class.java)
      @Suppress("UNCHECKED_CAST")
      method.invoke(null, context, requests) as List<MathMetrics>
    } catch (_: Exception) {
      requests.map { estimateMathFallback(it) }
    }
  }

  private fun estimateMathFallback(request: MathMeasureRequest): MathMetrics {
    val estimatedHeight = request.fontSize * 1.4f
    return MathMetrics(
      width =
        (request.fontSize * request.latex.length * 0.5f)
          .coerceIn(request.fontSize, request.fontSize * 20f)
          .toInt(),
      ascent = estimatedHeight * 0.7f,
      descent = estimatedHeight * 0.3f,
    )
  }
}
