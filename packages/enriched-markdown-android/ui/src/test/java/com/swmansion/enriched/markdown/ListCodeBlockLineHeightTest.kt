package com.swmansion.enriched.markdown

import android.text.Layout
import android.text.SpannableString
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.MarkerCanvas
import com.swmansion.enriched.markdown.test.TestAstFactory.codeBlock
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** A list's line height applies to its own text, not to the code blocks inside its items. */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ListCodeBlockLineHeightTest {
  @Test
  fun listLineHeightLeavesCodeBlockLinesAlone() {
    val natural = layout(listLineHeight = 0f)
    val tall = layout(listLineHeight = TALL_LINE_HEIGHT)

    // The layout's first and last lines add their font's padding, so check one in between.
    assertEquals("the list's own text takes the line height", TALL_LINE_HEIGHT.toInt(), tall.height("Next"))
    for (line in listOf("first line", "last line")) {
      assertEquals("height of \"$line\"", natural.height(line), tall.height(line))
    }
  }

  private fun layout(listLineHeight: Float): Rendered {
    val base = MarkdownRenderTestSupport.defaultStyle
    val style = MarkdownRenderTestSupport.styleWithList(base.listStyle.copy(lineHeight = listLineHeight))
    val list =
      unorderedList(
        listItem(paragraph(text("Item")), codeBlock("first line\nlast line\n")),
        listItem(paragraph(text("Next"))),
        listItem(paragraph(text("Last"))),
      )
    val text = SpannableString(render(document(list), style))
    return Rendered(text, MarkerCanvas.layout(text, style.listStyle.fontSize))
  }

  private class Rendered(
    val text: CharSequence,
    val layout: Layout,
  ) {
    fun height(content: String): Int {
      val start = text.indexOf(content)
      require(start >= 0) { "Rendered text does not contain \"$content\": \"$text\"" }
      val line = layout.getLineForOffset(start)
      return layout.getLineBottom(line) - layout.getLineTop(line)
    }
  }

  private companion object {
    const val TALL_LINE_HEIGHT = 120f
  }
}
