#!/bin/sh
# Builds the input core's JNI library for the host machine, so the JVM unit tests
# (Robolectric) can load it as `enriched_markdown_input_host`, in place of the
# `react_codegen_EnrichedMarkdownTextSpec` library the Kotlin wrappers load on a device.
# Only what the input needs is compiled: the shared input module, the md4c parser and
# its C sources, and src/main/cpp/input-jni.cpp.
#
# Usage: build.sh <core cpp dir> <output dir> <java home>
set -eu

CPP_ROOT=$1
OUT_DIR=$2
JAVA_HOME_DIR=$3
HERE=$(cd "$(dirname "$0")" && pwd)
JNI_SOURCE="$HERE/../../main/cpp/input-jni.cpp"

case "$(uname -s)" in
  Darwin) PLATFORM=darwin; EXTENSION=dylib ;;
  *) PLATFORM=linux; EXTENSION=so ;;
esac

OBJ_DIR="$OUT_DIR/obj"
rm -rf "$OBJ_DIR"
mkdir -p "$OBJ_DIR"

for source in "$CPP_ROOT"/enrmrkd/*.c; do
  ${CC:-cc} -std=c11 -O1 -fPIC -DENRMRKD_USE_UTF8=1 -I"$CPP_ROOT/enrmrkd" \
    -c "$source" -o "$OBJ_DIR/$(basename "$source").o"
done

${CXX:-c++} -std=c++17 -O1 -fPIC -shared -DENRMRKD_USE_UTF8=1 \
  -I"$JAVA_HOME_DIR/include" -I"$JAVA_HOME_DIR/include/$PLATFORM" \
  -I"$CPP_ROOT/input" -I"$CPP_ROOT/parser" -I"$CPP_ROOT/enrmrkd" \
  "$OBJ_DIR"/*.o "$CPP_ROOT"/input/*.cpp "$CPP_ROOT/parser/MD4CParser.cpp" "$JNI_SOURCE" \
  -o "$OUT_DIR/libenriched_markdown_input_host.$EXTENSION"
