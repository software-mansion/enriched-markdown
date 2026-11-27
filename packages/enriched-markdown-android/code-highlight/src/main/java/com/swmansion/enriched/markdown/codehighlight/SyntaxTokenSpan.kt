package com.swmansion.enriched.markdown.codehighlight

import android.text.style.ForegroundColorSpan

/**
 * The color of one syntax token in a code block. Only tokens whose [type] has a color get one;
 * the rest of the block keeps the code block's own text color.
 */
class SyntaxTokenSpan internal constructor(
  val type: SyntaxTokenType,
  color: Int,
) : ForegroundColorSpan(color)
