package com.swmansion.enriched.markdown.test

import android.content.Context
import android.text.SpannableString
import androidx.test.core.app.ApplicationProvider
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.styles.StrikethroughStyle
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.UnderlineStyle

object MarkdownRenderTestSupport {
  private val context: Context = ApplicationProvider.getApplicationContext()

  val defaultStyle: StyleConfig get() = StyleConfig.default(context)

  fun render(
    document: MarkdownASTNode,
    style: StyleConfig = defaultStyle,
  ): SpannableString {
    val renderer = Renderer()
    renderer.configure(style, context)
    return renderer.renderDocument(document, null, null)
  }

  /** [defaultStyle] with only the inline line-decoration colors replaced. */
  fun styleWithDecorationColors(
    strikethroughColor: Int? = null,
    underlineColor: Int? = null,
  ): StyleConfig {
    val base = defaultStyle
    return StyleConfig(
      paragraphStyleDefault = base.paragraphStyle,
      headingStyles = base.headingStyles,
      headingTypefaces = base.headingTypefaces,
      linkStyle = base.linkStyle,
      strongStyle = base.strongStyle,
      emphasisStyle = base.emphasisStyle,
      strikethroughStyle = StrikethroughStyle(color = strikethroughColor),
      underlineStyle = UnderlineStyle(color = underlineColor),
      codeStyle = base.codeStyle,
      imageStyle = base.imageStyle,
      inlineImageStyle = base.inlineImageStyle,
      blockquoteStyle = base.blockquoteStyle,
      listStyle = base.listStyle,
      codeBlockStyle = base.codeBlockStyle,
      thematicBreakStyle = base.thematicBreakStyle,
    )
  }
}
