@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.plugin

import android.content.Context
import android.util.Log
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.renderer.NodeRenderer
import com.swmansion.enriched.markdown.renderer.RendererConfig

@InternalPluginApi
class BlockSegmentRegistration internal constructor(
  val pluginId: String,
  val segment: PluginBlockSegment<*>,
)

/**
 * What a set of plugins registered, as an immutable value. Each view builds one from the plugins
 * passed to it, and rendering entry points take it as a parameter.
 *
 * Only its contents are [InternalPluginApi], so rendering entry points can take one without
 * making their callers opt in.
 */
class PluginSnapshot internal constructor(
  @property:InternalPluginApi
  val nodeRenderers: Map<NodeType, (RendererConfig, Context) -> NodeRenderer>,
  @property:InternalPluginApi
  val blockSegments: Map<NodeType, BlockSegmentRegistration>,
) {
  companion object {
    val EMPTY = PluginSnapshot(emptyMap(), emptyMap())

    /**
     * Later plugins win a node type that several claim. Of several plugins with the same id only
     * the last is installed, at its own position, so it replaces the earlier ones entirely.
     */
    @InternalPluginApi
    fun of(vararg plugins: MarkdownPlugin): PluginSnapshot =
      build(
        plugins
          .reversed()
          .distinctBy { it.id }
          .reversed()
          .map { plugin -> Registrations(plugin.id).also(plugin::install) },
      )

    internal fun build(installed: Collection<Registrations>): PluginSnapshot {
      if (installed.isEmpty()) return EMPTY

      val nodeRenderers = LinkedHashMap<NodeType, (RendererConfig, Context) -> NodeRenderer>()
      val nodeRendererOwners = HashMap<NodeType, String>()
      val blockSegments = LinkedHashMap<NodeType, BlockSegmentRegistration>()

      // Plugin order, so a later plugin wins a contested node type.
      for (registrations in installed) {
        val pluginId = registrations.pluginId

        for ((type, factory) in registrations.nodeRenderers) {
          warnOnConflict("node renderer", type, nodeRendererOwners.put(type, pluginId), pluginId)
          nodeRenderers[type] = factory
        }

        for ((type, segment) in registrations.blockSegments) {
          warnOnConflict("block segment", type, blockSegments[type]?.pluginId, pluginId)
          blockSegments[type] = BlockSegmentRegistration(pluginId, segment)
        }
      }

      return PluginSnapshot(nodeRenderers, blockSegments)
    }

    private fun warnOnConflict(
      kind: String,
      type: NodeType,
      previousOwner: String?,
      newOwner: String,
    ) {
      if (previousOwner == null || previousOwner == newOwner) return
      Log.w(TAG, "Plugins '$previousOwner' and '$newOwner' both claim $kind for $type; '$newOwner' wins.")
    }

    private const val TAG = "MarkdownPlugins"
  }

  internal class Registrations(
    val pluginId: String,
  ) : PluginRegistry {
    val nodeRenderers = LinkedHashMap<NodeType, (RendererConfig, Context) -> NodeRenderer>()
    val blockSegments = LinkedHashMap<NodeType, PluginBlockSegment<*>>()

    override fun registerNodeRenderer(
      type: NodeType,
      factory: (RendererConfig, Context) -> NodeRenderer,
    ) {
      nodeRenderers[type] = factory
    }

    override fun registerBlockSegment(
      type: NodeType,
      segment: PluginBlockSegment<*>,
    ) {
      blockSegments[type] = segment
    }
  }
}
