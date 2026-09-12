package com.swmansion.enriched.markdown.compose.style

import android.content.Context
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.Density

internal class StyleResolveContext(
  val context: Context,
  val density: Density,
  val fontFamilyResolver: FontFamily.Resolver,
)
