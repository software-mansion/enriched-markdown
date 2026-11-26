package com.swmansion.enriched.markdown

import com.facebook.react.internal.featureflags.ReactNativeFeatureFlagsForTests
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class EnrichedMarkdownTextPackageTest {
  // EnrichedMarkdownBlockSlotManager is a ReactViewManager, whose constructor reads a feature
  // flag; the default native accessor cannot load in a JVM test. This swaps a process-wide
  // accessor for one that returns the defaults, and is not restored.
  @Before
  fun setUp() {
    ReactNativeFeatureFlagsForTests.setUp()
  }

  // The names the JS components are registered under: React Native asks for a manager by name,
  // and a name that makes no manager, or the wrong one, fails only when JS first uses that view.
  @Test
  fun everyComponentNameMakesItsManager() {
    val names = listOf("EnrichedMarkdownText", "EnrichedMarkdown", "EnrichedMarkdownTextInput", "EnrichedMarkdownBlockSlot")
    assertEquals(names, EnrichedMarkdownTextPackage.VIEW_MANAGER_NAMES)
    for (name in names) {
      assertEquals(name, EnrichedMarkdownTextPackage.createManager(name)?.name)
    }
  }

  @Test
  fun anUnknownNameMakesNoManager() {
    assertNull(EnrichedMarkdownTextPackage.createManager("RCTView"))
  }
}
