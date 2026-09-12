package com.swmansion.enriched.markdown.test

import android.text.Spannable
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue

object MarkdownRenderAssertions {
  fun Spannable.assertContains(expected: String) {
    assertTrue(
      "Expected rendered text to contain \"$expected\" but was: \"${toString().replace('\n', '\\')}\"",
      toString().contains(expected),
    )
  }

  fun Spannable.assertHasSpan(spanClass: Class<*>) {
    assertTrue(
      "Expected span ${spanClass.simpleName} but found none",
      getSpans(0, length, spanClass).isNotEmpty(),
    )
  }

  fun Spannable.assertSpanCovers(
    text: String,
    spanClass: Class<*>,
  ) {
    val rendered = toString()
    val start = rendered.indexOf(text)
    assertTrue("Expected rendered text to contain \"$text\" but was: \"$rendered\"", start >= 0)
    val end = start + text.length
    assertTrue(
      "Expected ${spanClass.simpleName} to cover \"$text\"",
      getSpans(start, end, spanClass).isNotEmpty(),
    )
  }

  fun Spannable.assertLinkUrl(expectedUrl: String) {
    val links = getSpans(0, length, com.swmansion.enriched.markdown.spans.LinkSpan::class.java)
    assertTrue("Expected a LinkSpan", links.isNotEmpty())
    assertEquals(expectedUrl, links.first().url)
  }
}
