package android.widget

/** Selection-only surface for production MarkdownExtractor tests. */
open class TextView {
  var text: CharSequence = ""
  var selectionStart: Int = -1
  var selectionEnd: Int = -1
}
