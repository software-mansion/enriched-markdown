# JNI: Classes accessed from C++ via fbjni JavaClass descriptors.
# R8 cannot trace hardcoded string lookups in native code.

-keep class com.swmansion.enriched.markdown.parser.MarkdownASTNode { *; }
-keep class com.swmansion.enriched.markdown.parser.MarkdownASTNode$NodeType { *; }
-keep class com.swmansion.enriched.markdown.parser.Md4cFlags { *; }
-keep class com.swmansion.enriched.markdown.parser.Parser { *; }
