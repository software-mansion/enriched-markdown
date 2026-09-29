#!/usr/bin/env bash
set -euo pipefail

# Compile the real Android AST recognition helper on the JVM. This deliberately
# avoids Gradle, React Native and the Android SDK so parser behavior is testable
# without starting an app or connecting a device.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
android_dir="$repo_root/packages/react-native-enriched-markdown/android"
output_dir="$repo_root/build/text-link-recognizer-tests"

if [[ -n "${KOTLIN_HOME:-}" ]]; then
  kotlin_compiler="$KOTLIN_HOME/bin/kotlinc"
else
  kotlin_compiler="$(command -v kotlinc || true)"
fi
if [[ -n "${JAVA_HOME:-}" ]]; then
  java_runner="$JAVA_HOME/bin/java"
else
  java_runner="$(command -v java || true)"
fi
if [[ ! -x "$kotlin_compiler" || ! -x "$java_runner" ]]; then
  echo "A JDK and Kotlin compiler are required. Set JAVA_HOME and KOTLIN_HOME or add java and kotlinc to PATH." >&2
  exit 1
fi

mkdir -p "$output_dir"
extra_sources=()
if [[ "${1:-}" == "--native" ]]; then
  if [[ "$(uname -s)" != "Linux" || -z "${JAVA_HOME:-}" ]]; then
    echo "The optional JNI integration runner requires Linux and JAVA_HOME." >&2
    exit 1
  fi
  cpp_dir="$repo_root/packages/core/cpp"
  shim_dir="$android_dir/src/test/jvm-shims"
  "${CC:-cc}" -std=c11 -fPIC -DMD4C_USE_UTF8=1 \
    -I"$cpp_dir/md4c" -c "$cpp_dir/md4c/md4c.c" -o "$output_dir/md4c.o"
  "${CXX:-c++}" -std=c++17 -fPIC -shared -DMD4C_USE_UTF8=1 \
    -I"$JAVA_HOME/include" -I"$JAVA_HOME/include/linux" \
    -I"$shim_dir" -I"$cpp_dir/md4c" -I"$cpp_dir/parser" -I"$cpp_dir/highlight" \
    "$android_dir/src/main/cpp/jni-adapter.cpp" \
    "$cpp_dir/parser/MD4CParser.cpp" \
    "$cpp_dir/highlight/CodeBlockHighlighter.cpp" \
    "$cpp_dir/highlight/CodeBlockLanguages.cpp" \
    "$output_dir/md4c.o" \
    -o "$output_dir/libreact_codegen_EnrichedMarkdownTextSpec.so"
  extra_sources=(
    "$android_dir/src/main/java/com/swmansion/enriched/markdown/parser/Parser.kt"
    "$android_dir/src/main/java/com/swmansion/enriched/markdown/utils/common/CodeBlockNode.kt"
    "$android_dir/src/main/java/com/swmansion/enriched/markdown/utils/common/serialization/MarkdownASTSerializer.kt"
    "$android_dir/src/main/java/com/swmansion/enriched/markdown/utils/text/conversion/MarkdownExtractor.kt"
    "$android_dir/src/test/java/com/swmansion/enriched/markdown/parser/ParserTextLinkIntegrationTest.kt"
    "$android_dir/src/test/jvm/com/swmansion/enriched/markdown/parser/RecognizedLinkCopyTest.kt"
    "$shim_dir/android/util/Log.kt"
    "$shim_dir/android/text/Spannable.kt"
    "$shim_dir/android/text/style/UnderlineSpan.kt"
    "$shim_dir/android/widget/TextView.kt"
    "$shim_dir/com/swmansion/enriched/markdown/EnrichedMarkdownText.kt"
    "$shim_dir/com/swmansion/enriched/markdown/spans/ExtractionSpans.kt"
    "$shim_dir/com/swmansion/enriched/markdown/utils/common/FeatureFlags.kt"
  )
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $0 [--native]" >&2
  exit 1
fi

"$kotlin_compiler" \
  "$android_dir/src/main/java/com/swmansion/enriched/markdown/parser/MarkdownASTNode.kt" \
  "$android_dir/src/main/java/com/swmansion/enriched/markdown/parser/TextLinkRecognizer.kt" \
  "$android_dir/src/main/java/com/swmansion/enriched/markdown/input/autolink/LinkRegexConfig.kt" \
  "$android_dir/src/test/java/com/swmansion/enriched/markdown/parser/TextLinkRecognizerTest.kt" \
  "${extra_sources[@]}" \
  -include-runtime -d "$output_dir/tests.jar"
"$java_runner" -cp "$output_dir/tests.jar" com.swmansion.enriched.markdown.parser.TextLinkRecognizerTest
if [[ "${1:-}" == "--native" ]]; then
  "$java_runner" -Djava.library.path="$output_dir" -cp "$output_dir/tests.jar" \
    com.swmansion.enriched.markdown.parser.ParserTextLinkIntegrationTest
  "$java_runner" -cp "$output_dir/tests.jar" com.swmansion.enriched.markdown.parser.RecognizedLinkCopyTest
fi
