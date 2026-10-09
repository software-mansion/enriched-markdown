package com.swmansion.enriched.markdown.compose.material3

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import com.swmansion.enriched.markdown.compose.MarkdownStyle
import com.swmansion.enriched.markdown.compose.markdownStyle

/**
 * A [MarkdownStyle] colored from a Material 3 [ColorScheme], so markdown matches the rest of the
 * app and follows it between light and dark schemes. Only colors come from the scheme; sizes,
 * fonts and spacing stay the library defaults.
 *
 * Provide it app-wide or pass it to a single view, and layer overrides on top with
 * [MarkdownStyle.merge]:
 *
 * ```
 * MaterialTheme(colorScheme = if (isSystemInDarkTheme()) darkColorScheme() else lightColorScheme()) {
 *   MarkdownTheme(style = rememberMaterialMarkdownStyle()) {
 *     EnrichedMarkdownText(markdown)
 *   }
 * }
 * ```
 *
 * Plugins own their styles, so their colors are not set here; add them with [MarkdownStyle.merge].
 */
fun materialMarkdownStyle(colorScheme: ColorScheme): MarkdownStyle {
  val admonitionColors = if (colorScheme.surface.luminance() < 0.5f) darkAdmonitionColors else lightAdmonitionColors

  return markdownStyle {
    paragraph { color = colorScheme.onSurface }
    h1 { color = colorScheme.onSurface }
    h2 { color = colorScheme.onSurface }
    h3 { color = colorScheme.onSurface }
    h4 { color = colorScheme.onSurface }
    h5 { color = colorScheme.onSurfaceVariant }
    h6 { color = colorScheme.onSurfaceVariant }
    link { color = colorScheme.primary }
    highlight {
      color = colorScheme.onTertiaryContainer
      backgroundColor = colorScheme.tertiaryContainer
    }
    code {
      color = colorScheme.tertiary
      backgroundColor = colorScheme.surfaceContainerHighest
      borderColor = colorScheme.outlineVariant
    }
    codeBlock {
      color = colorScheme.onSurface
      backgroundColor = colorScheme.surfaceContainer
      borderColor = colorScheme.outlineVariant
    }
    blockquote {
      color = colorScheme.onSurfaceVariant
      borderColor = colorScheme.outlineVariant
      backgroundColor = colorScheme.surfaceContainerLow
      admonitions {
        note { color = admonitionColors.note }
        tip { color = admonitionColors.tip }
        important { color = admonitionColors.important }
        warning { color = admonitionColors.warning }
        caution { color = colorScheme.error }
      }
    }
    list {
      color = colorScheme.onSurface
      bulletColor = colorScheme.onSurfaceVariant
      markerColor = colorScheme.onSurfaceVariant
    }
    taskList {
      checkedColor = colorScheme.primary
      checkmarkColor = colorScheme.onPrimary
      borderColor = colorScheme.outline
    }
    table {
      color = colorScheme.onSurface
      headerTextColor = colorScheme.onSurface
      headerBackgroundColor = colorScheme.surfaceContainerHigh
      rowEvenBackgroundColor = colorScheme.surface
      rowOddBackgroundColor = colorScheme.surfaceContainerLow
      borderColor = colorScheme.outlineVariant
    }
    thematicBreak { color = colorScheme.outlineVariant }
    spoiler { color = colorScheme.onSurfaceVariant }
  }
}

/**
 * [materialMarkdownStyle] for [colorScheme], rebuilt only when the scheme changes - which is how
 * it follows a switch between light and dark schemes.
 */
@Composable
fun rememberMaterialMarkdownStyle(colorScheme: ColorScheme = MaterialTheme.colorScheme): MarkdownStyle =
  remember(colorScheme) { materialMarkdownStyle(colorScheme) }

/** Material 3 has no tokens for these, so they keep GitHub's alert colors for each scheme brightness. */
private class AdmonitionColors(
  val note: Color,
  val tip: Color,
  val important: Color,
  val warning: Color,
)

private val lightAdmonitionColors =
  AdmonitionColors(
    note = Color(0xFF0969DA),
    tip = Color(0xFF1A7F37),
    important = Color(0xFF8250DF),
    warning = Color(0xFF9A6700),
  )

private val darkAdmonitionColors =
  AdmonitionColors(
    note = Color(0xFF4493F8),
    tip = Color(0xFF3FB950),
    important = Color(0xFFAB7DF8),
    warning = Color(0xFFD29922),
  )
