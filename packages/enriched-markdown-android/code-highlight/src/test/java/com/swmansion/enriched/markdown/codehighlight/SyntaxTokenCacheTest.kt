package com.swmansion.enriched.markdown.codehighlight

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.codehighlight.test.FakeTokenSource
import com.swmansion.enriched.markdown.codehighlight.test.FakeTokenSource.Companion.CODE
import com.swmansion.enriched.markdown.codehighlight.test.FakeTokenSource.Companion.LANGUAGE
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class SyntaxTokenCacheTest {
  @Test
  fun equalCodeHitsTheCacheWhateverItsInstance() {
    val source = FakeTokenSource()
    val cache = SyntaxTokenCache(source)

    val first = cache.tokens(CODE, LANGUAGE)
    val second = cache.tokens(StringBuilder(CODE).toString(), LANGUAGE)

    assertEquals(1, source.calls)
    assertEquals(first.toList(), second.toList())
  }

  /** Each entry is charged its digest, so blocks without tokens cannot pile up past the bound. */
  @Test
  fun entriesWithoutTokensAreStillEvicted() {
    val source = FakeTokenSource()
    // Room for two 32-byte digests and nothing else.
    val cache = SyntaxTokenCache(source, maxSizeBytes = 64)

    cache.tokens("a", "cobol")
    cache.tokens("b", "cobol")
    cache.tokens("c", "cobol")
    cache.tokens("a", "cobol")

    assertEquals(4, source.calls)
  }
}
