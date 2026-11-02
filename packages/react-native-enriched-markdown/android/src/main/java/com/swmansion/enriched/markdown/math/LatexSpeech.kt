package com.swmansion.enriched.markdown.math

import android.util.Log
import com.swmansion.enriched.markdown.accessibility.AccessibilityLabels

object LatexSpeech {
  init {
    try {
      System.loadLibrary("react_codegen_EnrichedMarkdownTextSpec")
    } catch (e: UnsatisfiedLinkError) {
      Log.e("LatexSpeech", "Failed to load native library", e)
    }
  }

  private external fun nativeSpokenForm(latex: String): String

  fun spokenForm(latex: String): String =
    try {
      nativeSpokenForm(latex)
    } catch (e: UnsatisfiedLinkError) {
      latex
    }
}

fun AccessibilityLabels.mathLabel(latex: String): String {
  val label =
    if (mathEquation.contains("{speech}")) {
      mathEquation.replace("{speech}", LatexSpeech.spokenForm(latex))
    } else {
      mathEquation
    }
  return label.replace("{latex}", latex)
}
