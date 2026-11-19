package com.swmansion.enriched.markdown

import android.app.Activity
import android.os.Looper
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.Parser
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
@LooperMode(LooperMode.Mode.PAUSED)
class TextLineLimitRenderTest {
  private val words = "a clamped preview of a message that keeps on growing".split(" ")

  private fun update(count: Int): Pair<String, MarkdownASTNode> {
    val tail = words.take(count).joinToString(" ")
    val document = MarkdownASTNode(MarkdownASTNode.NodeType.Document, children = listOf(paragraph(text("first")), paragraph(text(tail))))
    return "first\n\n$tail" to document
  }

  private fun awaitText(
    view: EnrichedMarkdownText,
    markdown: String,
  ) {
    val deadline = System.currentTimeMillis() + 5000
    while (view.renderedMarkdown != markdown) {
      shadowOf(Looper.getMainLooper()).idle()
      assertTrue("never rendered $markdown", System.currentTimeMillis() < deadline)
      Thread.sleep(5)
    }
    shadowOf(Looper.getMainLooper()).idle()
  }

  // A clamped view copies its text, so a patch would be refused and render once more in full.
  @Test
  fun aLineLimitedViewRendersEachUpdateOnce() {
    val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    val view = EnrichedMarkdownText(activity)
    view.id = 3
    activity.setContentView(view)
    view.setMarkdownStyle(MarkdownRenderTestSupport.exportStyleMap())
    view.setMarkdownNumberOfLines(3)

    val keyBefore = view.textRenderKey
    var last = ""
    for (count in 1..5) {
      val (markdown, ast) = update(count)
      Parser.shared.remember(markdown, ast)
      view.setMarkdownContent(markdown)
      view.commitProps()
      awaitText(view, markdown)
      last = words.take(count).joinToString(" ")
    }

    assertEquals("renders in full", keyBefore, view.textRenderKey)
    assertTrue(view.text.toString(), view.text.toString().endsWith(last))
    assertTrue(view.text.toString().startsWith("first"))
    view.cleanup()
  }
}
