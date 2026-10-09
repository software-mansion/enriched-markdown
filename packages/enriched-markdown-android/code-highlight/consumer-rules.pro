# JNI: libenriched_markdown_highlight.so binds Java_..._CodeHighlighterNative_highlight by name.
# R8 cannot see that lookup, so keep the class name and its native methods.

-keepclasseswithmembernames,includedescriptorclasses class com.swmansion.enriched.markdown.codehighlight.CodeHighlighterNative {
  native <methods>;
}
