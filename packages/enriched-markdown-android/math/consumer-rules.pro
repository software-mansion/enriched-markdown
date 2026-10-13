-keep class io.ratex.** { *; }

# The Compose compiler annotates every class in this artifact with
# androidx.compose.runtime.internal.StabilityInferred, but Compose is compileOnly here, so a
# View-only app does not have it. The annotation is not visible at runtime; only R8's
# missing-class check would trip on it.
-dontwarn androidx.compose.runtime.**
