@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.accessibility

import android.graphics.Canvas
import android.graphics.Paint
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ReplacementSpan
import android.view.View
import android.widget.TextView
import androidx.core.view.accessibility.AccessibilityNodeInfoCompat
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PluginInlineSpan
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.link
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28, 35])
class MarkdownAccessibilityHelperTest {
  private class FormulaSpan :
    ReplacementSpan(),
    PluginInlineSpan {
    override fun toMarkdownSource(): String = "\$E=mc^2\$"

    override fun toHtmlText(): String? = null

    override fun toPlainText(): String? = null

    override fun toAccessibilityLabel(): String = "Math: E equals m c squared"

    override fun getSize(
      paint: Paint,
      text: CharSequence?,
      start: Int,
      end: Int,
      fm: Paint.FontMetricsInt?,
    ): Int = 10

    override fun draw(
      canvas: Canvas,
      text: CharSequence?,
      start: Int,
      end: Int,
      x: Float,
      top: Int,
      y: Int,
      bottom: Int,
      paint: Paint,
    ) = Unit
  }

  private fun nodes(
    text: CharSequence,
    count: Int,
  ): List<AccessibilityNodeInfoCompat> {
    val textView =
      TextView(ApplicationProvider.getApplicationContext()).apply {
        this.text = text
        measure(
          View.MeasureSpec.makeMeasureSpec(600, View.MeasureSpec.EXACTLY),
          View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
        )
      }
    val helper = MarkdownAccessibilityHelper(textView)
    helper.invalidateAccessibilityItems()
    val provider = helper.getAccessibilityNodeProvider(textView)!!
    return (0 until count).map { provider.createAccessibilityNodeInfo(it)!! }
  }

  @Test
  fun inlineFormulaIsItsOwnElement() {
    val text =
      SpannableStringBuilder("Energy ")
        .append("￼", FormulaSpan(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        .append(" is famous")

    assertEquals(
      listOf("Energy", "Math: E equals m c squared", "is famous"),
      nodes(text, 3).map { it.contentDescription.toString() },
    )
  }

  @Test
  fun formulaInsideLinkIsReadAsPartOfTheLink() {
    val text = render(document(paragraph(text("see "), link("https://example.com", text("x here")))))
    val formula = text.indexOf("x here")
    text.setSpan(FormulaSpan(), formula, formula + 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)

    val nodes = nodes(text, 2)
    assertEquals(listOf("see", "Math: E equals m c squared here"), nodes.map { it.contentDescription.toString() })
    assertTrue(nodes[1].isClickable)
  }
}
