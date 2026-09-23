@file:OptIn(InternalPluginApi::class)

package swmansion.enriched.markdown.android.example

import android.app.Application
import com.swmansion.enriched.markdown.math.LatexMathPlugin
import com.swmansion.enriched.markdown.plugin.EnrichedMarkdownPlugins
import com.swmansion.enriched.markdown.plugin.InternalPluginApi

/**
 * Math ships as its own artifact (`com.swmansion.enriched.markdown:math`), so rendering it takes
 * two switches: this one-off registration, and `Md4cFlags(latexMath = true)` on every
 * `EnrichedMarkdownText` that should parse `$...$` / `$$...$$` at all.
 *
 * Comment the `install` call out to see the fallback: equations show up as their raw source,
 * delimiters included, and logcat carries a single `EnrichedMarkdown` warning naming the artifact.
 */
class ExampleApplication : Application() {
  override fun onCreate() {
    super.onCreate()
    EnrichedMarkdownPlugins.install(LatexMathPlugin)
  }
}
