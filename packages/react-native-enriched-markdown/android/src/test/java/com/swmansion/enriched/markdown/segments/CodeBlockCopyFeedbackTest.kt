package com.swmansion.enriched.markdown.segments

import android.os.Looper
import android.widget.ImageButton
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class CodeBlockCopyFeedbackTest {
  private val copyLabel = "Copy code"

  @Test
  fun copyShowsCheckmarkThenRestoresCopyIcon() {
    // GIVEN
    val view = given_codeBlockView()

    // WHEN
    when_copyPressed(view)

    // THEN
    assertTrue(view.showsCopyFeedback)
    then_timePasses(CodeBlockContainerView.COPY_FEEDBACK_DURATION_MS)
    assertFalse(view.showsCopyFeedback)
  }

  @Test
  fun repeatedCopyRestartsTheFeedbackInterval() {
    // GIVEN
    val view = given_codeBlockView()
    when_copyPressed(view)
    then_timePasses(CodeBlockContainerView.COPY_FEEDBACK_DURATION_MS - 500)

    // WHEN
    when_copyPressed(view)
    then_timePasses(1000)

    // THEN
    assertTrue(view.showsCopyFeedback)
    then_timePasses(500)
    assertFalse(view.showsCopyFeedback)
  }

  @Test
  fun codeChangeResetsFeedback() {
    // GIVEN
    val view = given_codeBlockView()
    when_copyPressed(view)

    // WHEN
    view.applyCodeBlockNode(codeBlock("other"))

    // THEN
    assertFalse(view.showsCopyFeedback)
  }

  @Test
  fun becomingPendingResetsFeedback() {
    // GIVEN
    val view = given_codeBlockView()
    when_copyPressed(view)

    // WHEN
    view.pending = true

    // THEN
    assertFalse(view.showsCopyFeedback)
  }

  @Test
  fun copyStillFiresOnCopyPressOnce() {
    // GIVEN
    val view = given_codeBlockView()
    val actual = mutableListOf<Pair<String, String>>()
    view.dynamicProps.onCopyPress = { code, language -> actual += code to language }

    // WHEN
    when_copyPressed(view)

    // THEN
    assertEquals(listOf("let x = 1" to "js"), actual)
  }

  private fun given_codeBlockView(): CodeBlockContainerView =
    CodeBlockContainerView(RuntimeEnvironment.getApplication(), MarkdownRenderTestSupport.styleConfig()).apply {
      dynamicProps = DynamicBlockProps().apply { copyLabel = this@CodeBlockCopyFeedbackTest.copyLabel }
      applyCodeBlockNode(codeBlock("let x = 1"))
    }

  private fun when_copyPressed(view: CodeBlockContainerView) {
    (0 until view.childCount)
      .map(view::getChildAt)
      .filterIsInstance<ImageButton>()
      .first { it.contentDescription == copyLabel }
      .performClick()
  }

  private fun then_timePasses(millis: Long) {
    shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(millis))
  }

  private fun codeBlock(code: String) =
    MarkdownASTNode(
      NodeType.CodeBlock,
      attributes = mapOf("language" to "js"),
      children = listOf(MarkdownASTNode(NodeType.Text, content = code)),
    )
}
