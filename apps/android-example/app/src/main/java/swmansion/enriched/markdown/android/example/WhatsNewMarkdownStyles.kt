package swmansion.enriched.markdown.android.example

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.Typography
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swmansion.enriched.markdown.compose.MarkdownStyle
import com.swmansion.enriched.markdown.compose.markdownStyle

/**
 * Colors for the What's New screen: a clean off-white ground, the library's
 * navy as the one strong color, and its mint wherever something glows.
 */
object WhatsNewPalette {
  val ground = Color(0xFFF7F7F5)
  val card = Color.White

  /** The dark pane the markdown source is printed in. */
  val pane = Color(0xFF081242)
  val paneText = Color(0xFFD6ECDF)
  val ink = Color(0xFF14161E)
  val body = Color(0xFF2E313A)
  val muted = Color(0xFF707582)
  val rule = Color(0xFFE8E9EC)

  /** Sunken ground for inline code, quotes and striped table rows. */
  val well = Color(0xFFF0F2F9)

  /** Brand navy: masthead, links, bullets, numbers, table header. */
  val accent = Color(0xFF001A72)

  /** Brand mint: chip, number badge, checkmark, colophon label. */
  val mint = Color(0xFFBEEBD0)
  val note = Color(0xFF2B6CDE)
  val tip = Color(0xFF1C8C54)
  val important = Color(0xFF764AD4)
  val warning = Color(0xFFC4800C)
  val caution = Color(0xFFCE3A30)
}

/** Material scheme for the screen's own components, cut from the palette. */
val WhatsNewColorScheme: ColorScheme =
  lightColorScheme(
    primary = WhatsNewPalette.accent,
    onPrimary = Color.White,
    primaryContainer = WhatsNewPalette.mint,
    onPrimaryContainer = WhatsNewPalette.accent,
    background = WhatsNewPalette.ground,
    onBackground = WhatsNewPalette.ink,
    surface = WhatsNewPalette.card,
    onSurface = WhatsNewPalette.ink,
    surfaceVariant = WhatsNewPalette.well,
    onSurfaceVariant = WhatsNewPalette.muted,
    outline = WhatsNewPalette.rule,
    outlineVariant = WhatsNewPalette.rule,
  )

/** Montserrat throughout, so the page and the app's other screens share a voice. */
val WhatsNewTypography: Typography =
  Typography(
    headlineMedium =
      TextStyle(
        fontFamily = MontserratBold,
        fontSize = 30.sp,
        lineHeight = 36.sp,
        letterSpacing = (-0.6).sp,
      ),
    titleLarge =
      TextStyle(
        fontFamily = MontserratSemiBold,
        fontSize = 22.sp,
        lineHeight = 28.sp,
        letterSpacing = (-0.3).sp,
      ),
    bodyLarge =
      TextStyle(
        fontFamily = MontserratRegular,
        fontSize = 16.sp,
        lineHeight = 25.sp,
      ),
    bodyMedium =
      TextStyle(
        fontFamily = MontserratRegular,
        fontSize = 14.sp,
        lineHeight = 22.sp,
      ),
    bodySmall =
      TextStyle(
        fontFamily = MontserratRegular,
        fontSize = 12.sp,
        lineHeight = 18.sp,
      ),
    labelLarge =
      TextStyle(
        fontFamily = MontserratSemiBold,
        fontSize = 13.sp,
        letterSpacing = 0.4.sp,
      ),
    labelMedium =
      TextStyle(
        fontFamily = MontserratSemiBold,
        fontSize = 12.sp,
        letterSpacing = 0.6.sp,
      ),
    labelSmall =
      TextStyle(
        fontFamily = MontserratSemiBold,
        fontSize = 10.sp,
        letterSpacing = 1.4.sp,
      ),
  )

/**
 * Style for the feature cards: Montserrat prose on the white card, navy where
 * something signals, mint where something is checked or washed.
 */
val WhatsNewMarkdownStyle: MarkdownStyle =
  markdownStyle {
    paragraph {
      fontFamily = MontserratRegular
      fontSize = 15.sp
      color = WhatsNewPalette.body
      lineHeight = 24.sp
      marginBottom = 12.dp
    }
    strong {
      color = WhatsNewPalette.ink
    }
    link {
      color = WhatsNewPalette.accent
      underline = false
    }
    code {
      color = WhatsNewPalette.accent
      backgroundColor = WhatsNewPalette.well
      borderColor = WhatsNewPalette.well
    }
    strikethrough {
      color = WhatsNewPalette.muted
    }
    underline {
      color = WhatsNewPalette.accent
    }
    blockquote {
      fontFamily = MontserratRegular
      fontSize = 14.sp
      color = WhatsNewPalette.body
      lineHeight = 22.sp
      borderColor = WhatsNewPalette.accent
      borderWidth = 3.dp
      gapWidth = 12.dp
      backgroundColor = WhatsNewPalette.well
      marginBottom = 10.dp
      admonitions {
        note {
          color = WhatsNewPalette.note
          backgroundColor = WhatsNewPalette.note.copy(alpha = 0.08f)
        }
        tip {
          color = WhatsNewPalette.tip
          backgroundColor = WhatsNewPalette.tip.copy(alpha = 0.08f)
        }
        important {
          color = WhatsNewPalette.important
          backgroundColor = WhatsNewPalette.important.copy(alpha = 0.08f)
        }
        warning {
          color = WhatsNewPalette.warning
          backgroundColor = WhatsNewPalette.warning.copy(alpha = 0.08f)
        }
        caution {
          color = WhatsNewPalette.caution
          backgroundColor = WhatsNewPalette.caution.copy(alpha = 0.08f)
        }
      }
    }
    list {
      fontFamily = MontserratRegular
      fontSize = 15.sp
      color = WhatsNewPalette.body
      lineHeight = 24.sp
      bulletColor = WhatsNewPalette.accent
      markerColor = WhatsNewPalette.accent
      marginLeft = 4.dp
      gapWidth = 10.dp
      marginBottom = 6.dp
    }
    taskList {
      checkedColor = WhatsNewPalette.accent
      borderColor = WhatsNewPalette.muted
      checkmarkColor = WhatsNewPalette.mint
      checkboxSize = 18.dp
      checkboxBorderRadius = 5.dp
      checkedTextColor = WhatsNewPalette.muted
      checkedStrikethrough = true
    }
    table {
      fontFamily = MontserratRegular
      fontSize = 13.sp
      color = WhatsNewPalette.body
      lineHeight = 20.sp
      marginBottom = 4.dp
      headerFontFamily = MontserratSemiBold
      headerBackgroundColor = WhatsNewPalette.accent
      headerTextColor = WhatsNewPalette.mint
      rowEvenBackgroundColor = WhatsNewPalette.card
      rowOddBackgroundColor = WhatsNewPalette.well
      borderColor = WhatsNewPalette.rule
      borderWidth = 1.dp
      cornerRadius = 12.dp
      cellPaddingHorizontal = 12.dp
      cellPaddingVertical = 8.dp
    }
  }

/**
 * Style for the source pane: one fenced code block in the library's own
 * renderer, navy with mint-tinted mono text, no border, and no margins so
 * the card's spacing is the only spacing.
 */
val WhatsNewSourceStyle: MarkdownStyle =
  markdownStyle {
    codeBlock {
      fontFamily = CourierPrimeRegular
      fontSize = 12.5.sp
      color = WhatsNewPalette.paneText
      backgroundColor = WhatsNewPalette.pane
      borderColor = WhatsNewPalette.pane
      borderWidth = 0.dp
      cornerRadius = 14.dp
      padding = 14.dp
      marginTop = 0.dp
      marginBottom = 0.dp
    }
  }
