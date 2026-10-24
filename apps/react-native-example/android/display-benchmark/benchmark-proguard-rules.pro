# Keeps the instrumentation entry points R8 cannot see being reached reflectively.
-dontobfuscate
-ignorewarnings

-keepattributes *Annotation*

-keepclasseswithmembers @org.junit.runner.RunWith public class * { *; }
-keep class com.swmansion.enriched.markdown.benchmark.** { *; }
-keep class androidx.benchmark.** { *; }
-keep class androidx.test.** { *; }
-keep class org.junit.** { *; }
