package com.swmansion.enriched.markdown.utils.text.extensions

import android.text.SpannableStringBuilder

fun SpannableStringBuilder.isInlineImage(): Boolean {
  if (isEmpty()) return false
  val lastChar = last()
  return lastChar != '\n' && lastChar != '\u200B'
}
