package com.swmansion.enriched.markdown.parser

object LatexSpeech {
  init {
    Parser.shared
  }

  @JvmStatic
  private external fun nativeSpokenForm(latex: String): String

  fun spokenForm(latex: String): String =
    try {
      nativeSpokenForm(latex)
    } catch (e: UnsatisfiedLinkError) {
      latex
    }
}
