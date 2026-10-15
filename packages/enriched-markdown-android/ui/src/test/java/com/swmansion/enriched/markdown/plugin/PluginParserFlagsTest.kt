@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.plugin

import com.swmansion.enriched.markdown.parser.Md4cFlags
import org.junit.Assert.assertEquals
import org.junit.Test

class PluginParserFlagsTest {
  @Test
  fun withoutPluginsTheFlagsAreParsedAsSet() {
    val flags = Md4cFlags(underline = true)

    assertEquals(flags, PluginSnapshot.EMPTY.adjustParserFlags(flags))
  }

  @Test
  fun eachPluginTurnsOnWhatItNeedsOnTopOfTheViewsFlags() {
    val snapshot =
      PluginSnapshot.of(
        FlagPlugin("math") { it.copy(latexMath = true) },
        FlagPlugin("marks") { it.copy(highlight = true) },
      )

    assertEquals(
      Md4cFlags(underline = true, latexMath = true, highlight = true),
      snapshot.adjustParserFlags(Md4cFlags(underline = true)),
    )
  }

  @Test
  fun pluginsAdjustInOrderEachSeeingThePreviousResult() {
    val snapshot =
      PluginSnapshot.of(
        FlagPlugin("on") { it.copy(highlight = true) },
        FlagPlugin("off") { it.copy(highlight = false) },
      )

    assertEquals(Md4cFlags.Default, snapshot.adjustParserFlags(Md4cFlags.Default))
  }

  @Test
  fun aReplacedPluginNoLongerAdjustsTheFlags() {
    val snapshot =
      PluginSnapshot.of(
        FlagPlugin("same") { it.copy(latexMath = true) },
        FlagPlugin("same") { it },
      )

    assertEquals(Md4cFlags.Default, snapshot.adjustParserFlags(Md4cFlags.Default))
  }

  private class FlagPlugin(
    override val id: String,
    private val adjust: (Md4cFlags) -> Md4cFlags,
  ) : MarkdownPlugin {
    override fun install(registry: PluginRegistry) = Unit

    override fun adjustParserFlags(flags: Md4cFlags): Md4cFlags = adjust(flags)
  }
}
