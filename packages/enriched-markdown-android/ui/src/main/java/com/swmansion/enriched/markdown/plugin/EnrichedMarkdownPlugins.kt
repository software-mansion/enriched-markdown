package com.swmansion.enriched.markdown.plugin

import android.content.Context
import android.util.Log
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.renderer.NodeRenderer
import com.swmansion.enriched.markdown.renderer.RendererConfig

/**
 * The registrations in force for one render, as an immutable value.
 *
 * Renders run off the main thread while installs happen on it, so readers take the whole
 * snapshot once and keep it for the duration of their work: the maps behind it are never
 * mutated after publication, so a reader never sees a half-built registry and a render that
 * started before an install simply finishes against the older set.
 */
@InternalPluginApi
class PluginSnapshot internal constructor(
  val nodeRenderers: Map<NodeType, (RendererConfig, Context) -> NodeRenderer>,
  val blockSegments: Map<NodeType, BlockSegmentPlugin>,
  /** Owning plugin id per node type claimed as a block segment. */
  val blockSegmentOwners: Map<NodeType, String>,
  private val blockSegmentsByPluginId: Map<String, BlockSegmentPlugin>,
) {
  /** The plugin that owns an already-rendered segment, or null once it has been uninstalled. */
  fun blockSegmentFor(pluginId: String): BlockSegmentPlugin? = blockSegmentsByPluginId[pluginId]

  internal companion object {
    val EMPTY = PluginSnapshot(emptyMap(), emptyMap(), emptyMap(), emptyMap())
  }
}

/** Global, app-level registry. Thread-safe; reads take an immutable snapshot. */
@InternalPluginApi
object EnrichedMarkdownPlugins {
  private const val TAG = "EnrichedMarkdownPlugins"

  private val lock = Any()

  /** What each installed plugin registered, in install order. Guarded by [lock]. */
  private val installed = LinkedHashMap<String, Registrations>()

  /**
   * Published under [lock] and read without one: a render reads this once and works from the
   * value, so it costs nothing per node and cannot tear.
   */
  @Volatile
  var snapshot: PluginSnapshot = PluginSnapshot.EMPTY
    private set

  /** Installing an id that is already installed replaces its registrations, it does not add to them. */
  fun install(vararg plugins: MarkdownPlugin) {
    if (plugins.isEmpty()) return
    synchronized(lock) {
      for (plugin in plugins) {
        installed[plugin.id] = Registrations(plugin.id).also(plugin::install)
      }
      publish()
    }
  }

  fun uninstall(pluginId: String) {
    synchronized(lock) {
      if (installed.remove(pluginId) != null) publish()
    }
  }

  /** Test seam: drops every registration. */
  fun reset() {
    synchronized(lock) {
      installed.clear()
      snapshot = PluginSnapshot.EMPTY
    }
  }

  fun isInstalled(pluginId: String): Boolean = synchronized(lock) { installed.containsKey(pluginId) }

  private fun publish() {
    val nodeRenderers = LinkedHashMap<NodeType, (RendererConfig, Context) -> NodeRenderer>()
    val nodeRendererOwners = HashMap<NodeType, String>()
    val blockSegments = LinkedHashMap<NodeType, BlockSegmentPlugin>()
    val blockSegmentOwners = HashMap<NodeType, String>()
    val blockSegmentsByPluginId = HashMap<String, BlockSegmentPlugin>()

    // Install order, so a later install wins a contested node type.
    for (registrations in installed.values) {
      val pluginId = registrations.pluginId

      for ((type, factory) in registrations.nodeRenderers) {
        warnOnConflict("node renderer", type, nodeRendererOwners.put(type, pluginId), pluginId)
        nodeRenderers[type] = factory
      }

      for ((type, segment) in registrations.blockSegments) {
        warnOnConflict("block segment", type, blockSegmentOwners.put(type, pluginId), pluginId)
        blockSegments[type] = segment
        val previous = blockSegmentsByPluginId.put(pluginId, segment)
        if (previous != null && previous !== segment) {
          Log.w(
            TAG,
            "Plugin '$pluginId' registered more than one BlockSegmentPlugin instance. Views are " +
              "looked up by plugin id, so only the last one will be asked to create them; use a " +
              "single implementation that switches on node.type.",
          )
        }
      }
    }

    snapshot = PluginSnapshot(nodeRenderers, blockSegments, blockSegmentOwners, blockSegmentsByPluginId)
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

  private class Registrations(
    val pluginId: String,
  ) : PluginRegistry {
    val nodeRenderers = LinkedHashMap<NodeType, (RendererConfig, Context) -> NodeRenderer>()
    val blockSegments = LinkedHashMap<NodeType, BlockSegmentPlugin>()

    override fun registerNodeRenderer(
      type: NodeType,
      factory: (RendererConfig, Context) -> NodeRenderer,
    ) {
      nodeRenderers[type] = factory
    }

    override fun registerBlockSegment(
      type: NodeType,
      segment: BlockSegmentPlugin,
    ) {
      blockSegments[type] = segment
    }
  }
}
