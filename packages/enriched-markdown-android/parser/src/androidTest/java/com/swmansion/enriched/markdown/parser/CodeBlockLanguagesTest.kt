package com.swmansion.enriched.markdown.parser

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class CodeBlockLanguagesTest {
  @Test
  fun knownAliasMapsToItsDisplayName() {
    assertEquals("Python", CodeBlockLanguages.displayName("py"))
    assertEquals("C++", CodeBlockLanguages.displayName("cpp"))
  }

  @Test
  fun lookupIgnoresCase() {
    assertEquals("JavaScript", CodeBlockLanguages.displayName("JS"))
  }

  // The Kotlin fallback for a missing native library returns the fence string
  // untouched, so the capitalized result also proves the native lookup ran.
  @Test
  fun unknownLanguageIsCapitalized() {
    assertEquals("Zig", CodeBlockLanguages.displayName("zig"))
    assertEquals("Zig", CodeBlockLanguages.displayName("ZIG"))
  }

  @Test
  fun missingLanguageIsEmpty() {
    assertEquals("", CodeBlockLanguages.displayName(null))
    assertEquals("", CodeBlockLanguages.displayName(""))
  }
}
