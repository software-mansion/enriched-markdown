package com.swmansion.enriched.markdown.math

import com.swmansion.enriched.markdown.parser.LatexSpeech

fun interface MathAccessibilityLabel {
  fun resolve(latex: String): String

  companion object {
    const val DEFAULT_TEMPLATE = "Math: {speech}"

    val Default: MathAccessibilityLabel = template(DEFAULT_TEMPLATE)

    fun template(template: String): MathAccessibilityLabel = TemplateLabel(template)
  }
}

private data class TemplateLabel(
  val template: String,
) : MathAccessibilityLabel {
  private val speaks: Boolean = template.contains(SPEECH)

  override fun resolve(latex: String): String {
    val spoken = if (speaks) template.replace(SPEECH, LatexSpeech.spokenForm(latex)) else template
    return spoken.replace(LATEX, latex)
  }

  private companion object {
    const val SPEECH = "{speech}"
    const val LATEX = "{latex}"
  }
}
