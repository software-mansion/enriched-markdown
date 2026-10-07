@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.syntaxhighlighting

import android.text.style.ForegroundColorSpan
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PreservedColorSpan

/**
 * The color of one syntax token in a code block. Only tokens whose [type] has a color get one;
 * the rest of the block keeps the code block's own text color.
 */
class SyntaxTokenSpan internal constructor(
  val type: SyntaxTokenType,
  color: Int,
) : ForegroundColorSpan(color),
  PreservedColorSpan
