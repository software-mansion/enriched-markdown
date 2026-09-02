package swmansion.enriched.markdown.android.example

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swmansion.enriched.markdown.compose.MarkdownStyle
import com.swmansion.enriched.markdown.compose.markdownStyle

private val MontserratRegular = FontFamily(Font(R.font.montserrat_regular))
private val MontserratBold = FontFamily(Font(R.font.montserrat_bold))
private val MontserratSemiBold = FontFamily(Font(R.font.montserrat_semibold))
private val MontserratMedium = FontFamily(Font(R.font.montserrat_medium))
private val MontserratItalic = FontFamily(Font(R.font.montserrat_italic))
private val CourierPrimeRegular = FontFamily(Font(R.font.courier_prime_regular))

/**
 * Mirrors [apps/example/src/markdownStyles.ts] so the native Android example renders
 * with the same typography and colors as the React Native example app.
 */
val CustomMarkdownStyle: MarkdownStyle =
  markdownStyle {
    paragraph {
      fontFamily = MontserratRegular
      fontSize = 16.sp
      color = Color(0xFF1F2937)
      lineHeight = 26.sp
      marginBottom = 16.dp
    }
    h1 {
      fontFamily = MontserratBold
      fontSize = 30.sp
      color = Color(0xFF111827)
      lineHeight = 38.sp
      marginBottom = 8.dp
    }
    h2 {
      fontFamily = MontserratBold
      fontSize = 24.sp
      color = Color(0xFF111827)
      lineHeight = 32.sp
      marginBottom = 8.dp
    }
    h3 {
      fontFamily = MontserratSemiBold
      fontSize = 20.sp
      color = Color(0xFF1F2937)
      lineHeight = 28.sp
      marginBottom = 8.dp
    }
    h4 {
      fontFamily = MontserratSemiBold
      fontSize = 18.sp
      color = Color(0xFF1F2937)
      lineHeight = 26.sp
      marginBottom = 8.dp
    }
    h5 {
      fontFamily = MontserratMedium
      fontSize = 16.sp
      color = Color(0xFF374151)
      lineHeight = 24.sp
      marginBottom = 8.dp
    }
    h6 {
      fontFamily = MontserratMedium
      fontSize = 14.sp
      color = Color(0xFF4B5563)
      lineHeight = 22.sp
      marginBottom = 8.dp
    }
    blockquote {
      fontFamily = MontserratItalic
      fontSize = 16.sp
      color = Color(0xFF4B5563)
      lineHeight = 26.sp
      borderColor = Color(0xFFD1D5DB)
      borderWidth = 3.dp
      backgroundColor = Color(0xFFF9FAFB)
      gapWidth = 16.dp
      marginBottom = 16.dp
    }
    list {
      fontFamily = MontserratRegular
      fontSize = 16.sp
      color = Color(0xFF1F2937)
      lineHeight = 26.sp
      bulletColor = Color(0xFF6B7280)
      bulletSize = 6.dp
      markerMinWidth = 20.dp
      markerColor = Color(0xFF6B7280)
      markerFontWeight = FontWeight.Medium
      gapWidth = 8.dp
      marginLeft = 24.dp
      marginBottom = 16.dp
    }
    taskList {
      checkedColor = Color(0xFF2196F3)
      borderColor = Color(0xFF9E9E9E)
      checkmarkColor = Color(0xFFFFFFFF)
      checkboxSize = 14.dp
      checkboxBorderRadius = 3.dp
    }
    codeBlock {
      fontFamily = CourierPrimeRegular
      fontSize = 14.sp
      color = Color(0xFFF3F4F6)
      backgroundColor = Color(0xFF1F2937)
      borderColor = Color(0xFF374151)
      borderWidth = 1.dp
      cornerRadius = 8.dp
      padding = 16.dp
      lineHeight = 22.sp
      marginBottom = 16.dp
    }
    code {
      color = Color(0xFF7C3AED)
      backgroundColor = Color(0xFFF5F3FF)
      borderColor = Color(0xFFDDD6FE)
    }
    link {
      fontFamily = MontserratBold
      color = Color(0xFF2563EB)
      underline = true
    }
    strong {
      color = Color(0xFF111827)
    }
    emphasis {
      color = Color(0xFF4B5563)
    }
    image {
      height = 200.dp
      borderRadius = 8.dp
      marginBottom = 16.dp
    }
    inlineImage {
      size = 20.dp
    }
    thematicBreak {
      color = Color(0xFFE5E7EB)
      height = 1.dp
      marginTop = 24.dp
      marginBottom = 24.dp
    }
  }

/**
 * Mirrors the partial override used in [apps/example/src/screens/playground/PlaygroundScreen.tsx].
 */
val PlaygroundMarkdownStyle: MarkdownStyle =
  markdownStyle {
    link {
      color = Color(0xFF2563EB)
      underline = true
    }
    code {
      color = Color(0xFF7C3AED)
      backgroundColor = Color(0xFFF5F3FF)
    }
    codeBlock {
      color = Color(0xFFF3F4F6)
      backgroundColor = Color(0xFF1F2937)
      cornerRadius = 8.dp
    }
    blockquote {
      color = Color(0xFF4B5563)
      borderColor = Color(0xFFD1D5DB)
      borderWidth = 3.dp
      gapWidth = 12.dp
    }
  }
