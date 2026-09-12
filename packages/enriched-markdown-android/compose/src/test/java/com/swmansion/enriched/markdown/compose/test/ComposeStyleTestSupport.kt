package com.swmansion.enriched.markdown.compose.test

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFontFamilyResolver
import androidx.compose.ui.unit.Density
import androidx.test.core.app.ApplicationProvider
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext

internal object ComposeStyleTestSupport {
  val context: Context = ApplicationProvider.getApplicationContext()

  val testDensity: Density = Density(density = 2f, fontScale = 1f)

  @Composable
  fun rememberResolveContext(density: Density = testDensity): StyleResolveContext =
    StyleResolveContext(
      context = LocalContext.current,
      density = density,
      fontFamilyResolver = LocalFontFamilyResolver.current,
    )
}
