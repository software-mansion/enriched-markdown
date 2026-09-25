@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.test

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.text.SpannableStringBuilder
import android.text.style.ReplacementSpan
import android.view.View
import android.widget.TextView
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.plugin.BlockSegmentPlugin
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.MarkdownPlugin
import com.swmansion.enriched.markdown.plugin.PluginInlineSpan
import com.swmansion.enriched.markdown.plugin.PluginRegistry
import com.swmansion.enriched.markdown.plugin.PluginSegmentPayload
import com.swmansion.enriched.markdown.renderer.NodeRenderer
import com.swmansion.enriched.markdown.renderer.RendererConfig
import com.swmansion.enriched.markdown.renderer.RendererFactory
import com.swmansion.enriched.markdown.segments.SegmentViewConfig
import com.swmansion.enriched.markdown.styles.StyleConfig

/**
 * A plugin built only from core's own seam - no math engine, no `:math` module. It claims the latex
 * node types because they are the ones core leaves unrendered, but nothing here knows what latex is.
 */
class FakePlugin(
  override val id: String = ID,
  private val claimsInline: Boolean = true,
  private val claimsDisplay: Boolean = true,
  private val marker: String = id,
  private val segment: FakeBlockSegment = FakeBlockSegment(marker = marker),
) : MarkdownPlugin {
  val blockSegment: FakeBlockSegment get() = segment

  override fun install(registry: PluginRegistry) {
    if (claimsInline) {
      registry.registerNodeRenderer(MarkdownASTNode.NodeType.LatexMathInline) { config, _ ->
        FakeNodeRenderer(config, marker)
      }
    }
    if (claimsDisplay) {
      registry.registerBlockSegment(MarkdownASTNode.NodeType.LatexMathDisplay, segment)
    }
  }

  companion object {
    const val ID = "fake"

    /** [FakeBlockSegment.renderPayload] returns null for a node carrying this, to exercise the fallback. */
    const val DECLINE = "decline"
  }
}

class FakeNodeRenderer(
  private val config: RendererConfig,
  private val marker: String,
) : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    // Reads the config so a test can tell the plugin's renderer got the real one.
    val hasSink = config.onPluginEvent != null
    builder.append("[$marker:${node.content}:sink=$hasSink]")
  }
}

data class FakePayload(
  override val signatureSource: String,
) : PluginSegmentPayload

class FakeBlockSegment(
  private val marker: String = FakePlugin.ID,
) : BlockSegmentPlugin {
  var createdViews = 0
    private set
  var updatedViews = 0
    private set

  override fun renderPayload(
    node: MarkdownASTNode,
    style: StyleConfig,
    context: Context,
  ): PluginSegmentPayload? {
    if (node.content == FakePlugin.DECLINE) return null
    return FakePayload("$marker:${node.content}")
  }

  override fun createView(
    payload: PluginSegmentPayload,
    config: SegmentViewConfig,
  ): View {
    createdViews++
    return FakeSegmentView(config.context).apply { text = payload.signatureSource }
  }

  override fun updateView(
    view: View,
    payload: PluginSegmentPayload,
    config: SegmentViewConfig,
  ) {
    updatedViews++
    (view as FakeSegmentView).text = payload.signatureSource
  }

  override fun matchesView(view: View): Boolean = view is FakeSegmentView
}

class FakeSegmentView(
  context: Context,
) : TextView(context)

/** A plugin replacement span that round-trips through core's export without core knowing its syntax. */
class FakeInlineSpan(
  private val source: String,
  private val htmlText: String? = source,
) : ReplacementSpan(),
  PluginInlineSpan {
  override fun toMarkdownSource(): String = "@@$source@@"

  override fun toHtmlText(): String? = htmlText

  override fun toPlainText(): String = "plain:$source"

  override fun getSize(
    paint: Paint,
    text: CharSequence?,
    start: Int,
    end: Int,
    fm: Paint.FontMetricsInt?,
  ): Int = 1

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
