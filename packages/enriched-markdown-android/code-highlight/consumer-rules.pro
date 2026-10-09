# JNI: libenriched_markdown_highlight.so binds Java_..._CodeHighlighterNative_highlight by name.
# R8 cannot see that lookup, so keep the class name and its native methods.

-keepclasseswithmembernames,includedescriptorclasses class com.swmansion.enriched.markdown.codehighlight.CodeHighlighterNative {
  native <methods>;
}

# The Compose compiler annotates every class in this artifact with
# androidx.compose.runtime.internal.StabilityInferred, but Compose is compileOnly here, so a
# View-only app does not have it. The annotation is not visible at runtime; only R8's
# missing-class check would trip on it.
-dontwarn androidx.compose.runtime.**
