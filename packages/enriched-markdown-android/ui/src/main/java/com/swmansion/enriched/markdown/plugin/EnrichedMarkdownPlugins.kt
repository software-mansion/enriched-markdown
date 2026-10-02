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
  val segment: BlockSegmentPlugin<*>,
)

/**
 * The installed registrations, as an immutable value. Rendering entry points take one as a
 * parameter, defaulting to the registry's, so a test can render against plugins of its own
 * without touching the process-wide registry.
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

    /** A snapshot of [plugins] that bypasses the process-wide registry. */
    @InternalPluginApi
    fun of(vararg plugins: MarkdownPlugin): PluginSnapshot = build(plugins.map { plugin -> Registrations(plugin.id).also(plugin::install) })

    internal fun build(installed: Collection<Registrations>): PluginSnapshot {
      if (installed.isEmpty()) return EMPTY

      val nodeRenderers = LinkedHashMap<NodeType, (RendererConfig, Context) -> NodeRenderer>()
      val nodeRendererOwners = HashMap<NodeType, String>()
      val blockSegments = LinkedHashMap<NodeType, BlockSegmentRegistration>()

      // Install order, so a later install wins a contested node type.
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

    private const val TAG = "EnrichedMarkdownPlugins"
  }

  internal class Registrations(
    val pluginId: String,
  ) : PluginRegistry {
    val nodeRenderers = LinkedHashMap<NodeType, (RendererConfig, Context) -> NodeRenderer>()
    val blockSegments = LinkedHashMap<NodeType, BlockSegmentPlugin<*>>()

    override fun registerNodeRenderer(
      type: NodeType,
      factory: (RendererConfig, Context) -> NodeRenderer,
    ) {
      nodeRenderers[type] = factory
    }

    override fun registerBlockSegment(
      type: NodeType,
      segment: BlockSegmentPlugin<*>,
    ) {
      blockSegments[type] = segment
    }
  }
}

/**
 * Global, app-level registry. Plugins are installed once, at startup, before any markdown renders:
 * the first render freezes the registry, and a later [install] is ignored with a warning. Nothing
 * rendered can therefore disagree with what is installed, and a view never has to re-render
 * because the plugins changed under it.
 */
object EnrichedMarkdownPlugins {
  private val lock = Any()

  /** What each installed plugin registered, in install order. Guarded by [lock]. */
  private val installed = LinkedHashMap<String, PluginSnapshot.Registrations>()

  /** Guarded by [lock]; volatile so [snapshot] can skip the lock once it is set. */
  @Volatile
  private var frozen = false

  @Volatile
  private var current: PluginSnapshot = PluginSnapshot.EMPTY

  /** What renders use. Reading it freezes the registry. */
  val snapshot: PluginSnapshot
    get() {
      if (!frozen) synchronized(lock) { frozen = true }
      return current
    }

  /**
   * Installing an id that is already installed replaces its registrations, it does not add to
   * them. Ignored, with a warning, once anything has rendered.
   */
  fun install(vararg plugins: MarkdownPlugin) {
    if (plugins.isEmpty()) return
    synchronized(lock) {
      if (frozen) {
        Log.w(
          TAG,
          "Ignoring install of ${plugins.joinToString { "'${it.id}'" }}: markdown has already rendered. " +
            "Install plugins at startup, before any EnrichedMarkdown view renders.",
        )
        return
      }
      for (plugin in plugins) {
        installed[plugin.id] = PluginSnapshot.Registrations(plugin.id).also(plugin::install)
      }
      current = PluginSnapshot.build(installed.values)
    }
  }

  fun isInstalled(pluginId: String): Boolean = synchronized(lock) { installed.containsKey(pluginId) }

  /** Test seam: drops every registration and lifts the freeze. */
  @InternalPluginApi
  fun reset() {
    synchronized(lock) {
      installed.clear()
      current = PluginSnapshot.EMPTY
      frozen = false
    }
  }

  private const val TAG = "EnrichedMarkdownPlugins"
}
