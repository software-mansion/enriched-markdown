@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.plugin

import android.content.Context
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.TextPaint
import android.text.style.CharacterStyle
import android.text.style.ForegroundColorSpan
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.EnrichedMarkdown
import com.swmansion.enriched.markdown.spans.CodeBlockSpan
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.test.FakePlugin
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.defaultStyle
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.blockquote
import com.swmansion.enriched.markdown.test.TestAstFactory.codeBlock
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import com.swmansion.enriched.markdown.utils.text.conversion.MarkdownExtractor
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class CodeBlockDecoratorTest {
  private val context: Context = ApplicationProvider.getApplicationContext()

  // The registry is process-wide and the first render anywhere freezes it.
  @Before
  fun setUp() = EnrichedMarkdownPlugins.reset()

  @After
  fun tearDown() = EnrichedMarkdownPlugins.reset()

  @Test
  fun aTopLevelBlockIsDecoratedOverItsCodeWithItsLanguage() {
    val decorator = RecordingDecorator()

    render(document(paragraph(text("before")), codeBlock(CODE, "kotlin")), plugins = PluginSnapshot.of(DecoratingPlugin(decorator)))

    assertEquals(listOf(Decorated(CODE, "kotlin")), decorator.calls)
  }

  @Test
  fun aBlockInAListItemIsDecoratedOverItsCode() {
    val decorator = RecordingDecorator()

    render(
      document(unorderedList(listItem(paragraph(text("item")), codeBlock(CODE, "kotlin")))),
      plugins = PluginSnapshot.of(DecoratingPlugin(decorator)),
    )

    assertEquals(listOf(Decorated(CODE, "kotlin")), decorator.calls)
  }

  @Test
  fun aBlockInABlockquoteIsDecoratedOverItsCode() {
    val decorator = RecordingDecorator()

    render(
      document(blockquote(paragraph(text("quote")), codeBlock(CODE, "kotlin"))),
      plugins = PluginSnapshot.of(DecoratingPlugin(decorator)),
    )

    assertEquals(listOf(Decorated(CODE, "kotlin")), decorator.calls)
  }

  @Test
  fun aFenceWithoutALanguageIsDecoratedWithNone() {
    val decorator = RecordingDecorator()

    render(document(codeBlock(CODE), codeBlock(CODE, " ")), plugins = PluginSnapshot.of(DecoratingPlugin(decorator)))

    assertEquals(listOf(Decorated(CODE, null), Decorated(CODE, null)), decorator.calls)
  }

  @Test
  fun decoratorsRunInInstallOrderAndSeeTheRenderStyle() {
    val first = RecordingDecorator()
    val second = RecordingDecorator()
    val plugins = PluginSnapshot.of(DecoratingPlugin(first, id = "first"), DecoratingPlugin(second, id = "second"))

    val style = defaultStyle

    render(document(codeBlock(CODE)), style, plugins)

    assertEquals(listOf(first, second), plugins.codeBlockDecorators)
    assertSame(style, first.lastStyle)
    assertEquals(1, second.calls.size)
  }

  /** The block's span repaints every color it does not preserve, so a token span must come after it. */
  @Test
  fun aTokenColorSurvivesTheBlockTextColor() {
    val decorator = RecordingDecorator(tokenColor = TOKEN_COLOR)

    val rendered = render(document(codeBlock(CODE, "kotlin")), plugins = PluginSnapshot.of(DecoratingPlugin(decorator)))

    val blockColor = defaultStyle.codeBlockStyle.color
    assertNotEquals(blockColor, TOKEN_COLOR)
    assertEquals(TOKEN_COLOR, drawColorAt(rendered, rendered.indexOf("val")))
    // Outside the token the block's own color still applies.
    assertEquals(blockColor, drawColorAt(rendered, rendered.indexOf("println")))
  }

  /** A blockquote's span is a priority span, so it applies before the block's and the token's. */
  @Test
  fun aTokenColorSurvivesInABlockquote() {
    val decorator = RecordingDecorator(tokenColor = TOKEN_COLOR)

    val rendered =
      render(document(blockquote(codeBlock(CODE, "kotlin"))), plugins = PluginSnapshot.of(DecoratingPlugin(decorator)))

    assertEquals(TOKEN_COLOR, drawColorAt(rendered, rendered.indexOf("val")))
  }

  /**
   * A list item's span is set after its children and repaints colors it does not preserve; it
   * moves a [PreservedColorSpan] after itself, at every depth, so the token keeps its color.
   */
  @Test
  fun aPreservedTokenColorSurvivesInAListItem() {
    val decorator = RecordingDecorator(tokenColor = TOKEN_COLOR, preserved = true)

    val rendered =
      render(
        document(
          unorderedList(listItem(codeBlock(CODE, "kotlin"))),
          unorderedList(listItem(paragraph(text("outer")), unorderedList(listItem(codeBlock(NESTED_CODE, "kotlin"))))),
        ),
        plugins = PluginSnapshot.of(DecoratingPlugin(decorator)),
      )

    assertEquals(TOKEN_COLOR, drawColorAt(rendered, rendered.indexOf("val")))
    assertEquals(TOKEN_COLOR, drawColorAt(rendered, rendered.indexOf("var")))
  }

  /** An unmarked color is still repainted: the list item only moves spans that opted in. */
  @Test
  fun anUnmarkedTokenColorTakesTheListColor() {
    val decorator = RecordingDecorator(tokenColor = TOKEN_COLOR)

    val rendered =
      render(document(unorderedList(listItem(codeBlock(CODE, "kotlin")))), plugins = PluginSnapshot.of(DecoratingPlugin(decorator)))

    assertEquals(defaultStyle.listStyle.color, drawColorAt(rendered, rendered.indexOf("val")))
  }

  /**
   * Copy as Markdown walks span transitions; a color ending right before a line's "\n" must not
   * leave that "\n" to be read as a paragraph break, which dropped the closing fence.
   */
  @Test
  fun aDecoratorsSpansDoNotChangeCopyAsMarkdown() {
    val colorEveryLine =
      CodeBlockDecorator { builder, start, end, _, _, _ ->
        var lineStart = start
        while (lineStart < end) {
          val lineEnd = builder.indexOf('\n', lineStart).takeIf { it in lineStart until end } ?: end
          builder.setSpan(ForegroundColorSpan(TOKEN_COLOR), lineStart, lineEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
          lineStart = lineEnd + 1
        }
      }
    val doc = document(paragraph(text("before")), codeBlock(CODE, "kotlin"), unorderedList(listItem(codeBlock(CODE))))

    val plain = render(doc, plugins = PluginSnapshot.EMPTY)
    val decorated = render(doc, plugins = PluginSnapshot.of(DecoratingPlugin(colorEveryLine)))

    assertEquals(
      MarkdownExtractor.extractFromSpannable(plain, 0, plain.length),
      MarkdownExtractor.extractFromSpannable(decorated, 0, decorated.length),
    )
  }

  @Test
  fun withNoDecoratorTheRenderIsUnchanged() {
    val doc =
      document(
        codeBlock(CODE, "kotlin"),
        unorderedList(listItem(codeBlock(CODE))),
        blockquote(codeBlock(CODE, "kotlin")),
      )

    val baseline = render(doc, plugins = PluginSnapshot.EMPTY).describe()

    assertEquals(baseline, render(doc, plugins = PluginSnapshot.of(FakePlugin())).describe())
    assertEquals(
      baseline,
      render(
        doc,
        plugins =
          PluginSnapshot.of(
            DecoratingPlugin(
              CodeBlockDecorator {
                _,
                _,
                _,
                _,
                _,
                _,
                ->
              },
            ),
          ),
      ).describe(),
    )
  }

  @Test
  fun aDecoratorInstalledAppWideIsUsed() {
    val decorator = RecordingDecorator()
    EnrichedMarkdownPlugins.install(DecoratingPlugin(decorator))

    render(document(codeBlock(CODE, "kotlin")))

    assertEquals(listOf(Decorated(CODE, "kotlin")), decorator.calls)
  }

  /** The view's render path takes this snapshot; the parser it also needs is native, so it is not run. */
  @Test
  fun aDecoratorPassedToAViewReachesItsRenders() {
    val decorator = RecordingDecorator()
    val view = EnrichedMarkdown(context)
    view.setPlugins(listOf(DecoratingPlugin(decorator)))

    render(document(codeBlock(CODE, "kotlin")), plugins = view.pluginSnapshotForTest())

    assertEquals(listOf(Decorated(CODE, "kotlin")), decorator.calls)
  }

  /** What [TextPaint] ends up with after every character style at [index], in the order layout applies them. */
  private fun drawColorAt(
    text: Spanned,
    index: Int,
  ): Int {
    val paint = TextPaint()
    for (span in text.getSpans(index, index + 1, CharacterStyle::class.java)) {
      span.updateDrawState(paint)
    }
    return paint.color
  }

  private fun Spanned.describe(): List<String> =
    listOf(toString()) +
      getSpans(0, length, Any::class.java).map {
        "${it::class.java.name} ${getSpanStart(it)}..${getSpanEnd(it)} ${getSpanFlags(it)}"
      }

  private fun EnrichedMarkdown.pluginSnapshotForTest(): PluginSnapshot {
    val field = EnrichedMarkdown::class.java.getDeclaredField("pluginSnapshot")
    field.isAccessible = true
    return field.get(this) as PluginSnapshot
  }

  private data class Decorated(
    val code: String,
    val language: String?,
  )

  /**
   * Records each call; with a [tokenColor], colors the first word of the block like a keyword,
   * through a [PreservedColorSpan] when [preserved] is set.
   */
  private class RecordingDecorator(
    private val tokenColor: Int? = null,
    private val preserved: Boolean = false,
  ) : CodeBlockDecorator {
    val calls = mutableListOf<Decorated>()
    var lastStyle: StyleConfig? = null
      private set

    override fun decorate(
      builder: SpannableStringBuilder,
      start: Int,
      end: Int,
      language: String?,
      style: StyleConfig,
      context: Context,
    ) {
      // The block's own span is already over the range it is handed.
      val blockSpan = builder.getSpans(start, end, CodeBlockSpan::class.java).single()
      assertEquals(start, builder.getSpanStart(blockSpan))
      assertEquals(end, builder.getSpanEnd(blockSpan))

      calls += Decorated(builder.subSequence(start, end).toString(), language)
      lastStyle = style
      if (tokenColor != null) {
        val wordEnd = builder.indexOf(' ', start)
        val span = if (preserved) PreservedTokenSpan(tokenColor) else ForegroundColorSpan(tokenColor)
        builder.setSpan(span, start, wordEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
      }
    }
  }

  private class PreservedTokenSpan(
    color: Int,
  ) : ForegroundColorSpan(color),
    PreservedColorSpan

  private class DecoratingPlugin(
    private val decorator: CodeBlockDecorator,
    override val id: String = "decorating",
  ) : MarkdownPlugin {
    override fun install(registry: PluginRegistry) = registry.registerCodeBlockDecorator(decorator)
  }

  private companion object {
    const val CODE = "val answer = 42\nprintln(answer)\n"
    const val NESTED_CODE = "var count = 0\n"
    const val TOKEN_COLOR = 0xFF123456.toInt()
  }
}
