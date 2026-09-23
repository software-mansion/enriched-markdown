package com.swmansion.enriched.markdown.plugin

/**
 * Marks the extension surface plugins are built against. The plugins are written, shipped and
 * versioned alongside core, so the surface carries no semver promise and stays free to change.
 */
@RequiresOptIn("Internal extension API. Not supported for third-party use.", RequiresOptIn.Level.ERROR)
@Retention(AnnotationRetention.BINARY)
annotation class InternalPluginApi
