package com.swmansion.enriched.markdown.styles

/**
 * Identity-keyed handle for a plugin's style object. Plugins declare one per style type, as a
 * singleton, and core stores the value against it in [StyleConfig.extensions].
 *
 * Deliberately not a data class: two plugins are free to pick the same [name], and equality by
 * name would let one read - or silently overwrite - the other's style.
 */
class StyleExtensionKey<T : Any>(
  val name: String,
) {
  override fun toString(): String = "StyleExtensionKey($name)"
}
