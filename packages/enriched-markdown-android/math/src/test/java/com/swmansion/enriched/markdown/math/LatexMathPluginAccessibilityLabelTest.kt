@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.math

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.math.test.MathTestSupport.context
import com.swmansion.enriched.markdown.math.test.MathTestSupport.defaultStyle
import com.swmansion.enriched.markdown.parser.LatexSpeech
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PluginSnapshot
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class LatexMathPluginAccessibilityLabelTest {
  @Test
  fun theDefaultLabelSpeaksTheFormulaBehindTheMathPrefix() {
    val view = MathContainerView(context, defaultStyle).apply { applyPayload(MathSegmentPayload("x^2", null)) }

    assertEquals("Math: " + LatexSpeech.spokenForm("x^2"), view.contentDescription)
  }

  @Test
  fun aTemplateReplacesSpeechAndLatex() {
    assertEquals(
      LatexSpeech.spokenForm("x^2") + " (x^2)",
      MathAccessibilityLabel.template("{speech} ({latex})").resolve("x^2"),
    )
  }

  @Test
  fun aTemplateWithoutSpeechReadsTheSourceOnly() {
    assertEquals("Formel: x^2", MathAccessibilityLabel.template("Formel: {latex}").resolve("x^2"))
  }

  @Test
  fun thePluginHandsItsLabelToTheBlockSegment() {
    val snapshot = PluginSnapshot.of(LatexMathPlugin("Formel: {latex}"))

    val segment = snapshot.blockSegments.getValue(NodeType.LatexMathDisplay).segment as MathBlockSegment

    assertEquals("Formel: x^2", segment.accessibilityLabel.resolve("x^2"))
  }

  @Test
  fun aLambdaLabelsTheBlockView() {
    val view =
      MathContainerView(context, defaultStyle, accessibilityLabel = MathAccessibilityLabel { "Wzór: $it" }).apply {
        applyPayload(MathSegmentPayload("x^2", null))
      }

    assertEquals("Wzór: x^2", view.contentDescription)
  }

  @Test
  fun changingTheLabelRelabelsTheView() {
    val view = MathContainerView(context, defaultStyle).apply { applyPayload(MathSegmentPayload("x^2", null)) }

    view.accessibilityLabel = MathAccessibilityLabel.template("{latex}")

    assertEquals("x^2", view.contentDescription)
  }

  @Test
  fun pluginsWithTheSameTemplateAreEqual() {
    assertEquals(LatexMathPlugin, LatexMathPlugin())
    assertEquals(LatexMathPlugin("Formel: {latex}"), LatexMathPlugin("Formel: {latex}"))
    assertNotEquals(LatexMathPlugin, LatexMathPlugin("Formel: {latex}"))
  }
}
