package com.swmansion.enriched.markdown.accessibility

import android.text.SpannableStringBuilder
import android.text.Spanned
import android.view.View
import android.widget.TextView
import androidx.core.view.accessibility.AccessibilityNodeInfoCompat
import com.facebook.react.bridge.JavaOnlyMap
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.swmansion.enriched.markdown.spans.HeadingSpan
import com.swmansion.enriched.markdown.styles.StyleConfig
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class MarkdownAccessibilityHelperTest {
  private object FormulaSpan : SpokenSpan {
    override fun accessibilityLabel(labels: AccessibilityLabels): String = labels.mathEquation.replace("{speech}", "E equals m c squared")
  }

  private class Harness(
    text: CharSequence,
  ) {
    private val textView =
      TextView(RuntimeEnvironment.getApplication()).apply {
        this.text = text
        measure(
          View.MeasureSpec.makeMeasureSpec(600, View.MeasureSpec.EXACTLY),
          View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
        )
      }

    val helper = MarkdownAccessibilityHelper(textView).apply { labels = AccessibilityLabels(mathEquation = "Math: {speech}") }

    fun node(id: Int): AccessibilityNodeInfoCompat = helper.getAccessibilityNodeProvider(textView)!!.createAccessibilityNodeInfo(id)!!

    fun labels(count: Int): List<String> = (0 until count).map { node(it).contentDescription.toString() }
  }

  @Test
  fun spokenSpanBecomesItsOwnElement() {
    val harness =
      Harness(
        SpannableStringBuilder("Energy ")
          .append("￼", FormulaSpan, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
          .append(" is famous"),
      )
    assertEquals(listOf("Energy", "Math: E equals m c squared", "is famous"), harness.labels(3))

    harness.helper.labels = AccessibilityLabels(mathEquation = "Formel: {speech}")
    assertEquals("Formel: E equals m c squared", harness.node(1).contentDescription.toString())
  }

  @Test
  fun formulaInsideHeadingIsItsOwnElement() {
    val text = SpannableStringBuilder("Speech test ").append("￼", FormulaSpan, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    text.setSpan(headingSpan(level = 1), 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    val harness = Harness(text)

    assertEquals(listOf("Speech test", "Math: E equals m c squared"), harness.labels(2))
    assertEquals(listOf(true, false), (0 until 2).map { harness.node(it).isHeading })
  }

  @Test
  fun formulaInsideLinkTextIsSpokenInPlace() {
    val text =
      SpannableStringBuilder("see ")
        .append("￼", FormulaSpan, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        .append(" here")
    val labels = AccessibilityLabels(mathEquation = "Math: {speech}")
    assertEquals("see Math: E equals m c squared here", text.spokenText(0, text.length, labels))
  }

  private fun headingSpan(level: Int): HeadingSpan {
    val context = RuntimeEnvironment.getApplication()
    DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(context)
    val style = JavaOnlyMap()
    for (h in 1..6) {
      style.putMap("h$h", JavaOnlyMap.of("fontSize", 24.0, "color", -16777216.0, "marginTop", 0.0, "marginBottom", 0.0, "lineHeight", 32.0))
    }
    return HeadingSpan(level, StyleConfig(style, context, true, 0f))
  }
}
