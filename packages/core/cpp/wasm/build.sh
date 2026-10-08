#!/usr/bin/env bash
# Compile md4c + the WASM wrapper to a single self-contained JS file.
#
# Prerequisites:
#   brew install emscripten    # macOS
#   # or follow https://emscripten.org/docs/getting_started/downloads.html
#
# Usage:
#   bash packages/core/cpp/wasm/build.sh
#
# Output:
#   packages/react-native-enriched-markdown/src/web/wasm/md4c.js
#
# NOTE: the committed md4c.js is an artifact, and the docs under docs/ describe
# what the *committed* one can do - not what this source can. Nothing rebuilds
# it on install, prepare or prepack, so a change under packages/core/cpp reaches
# native immediately and web only once someone runs this script. It had been
# behind by a release cycle and a whole feature (#765's video blocks, which the
# web renderer already had a VideoRenderer for) before anyone noticed, which is
# why scripts/test-web-bundle.mjs now compares the committed bundle against the
# same golden AST dump as the host parser, in CI.
#
# That test catches a stale bundle, not stale prose: after rebuilding, re-read
# whatever docs/ says about what web does and does not support, and update it in
# the same commit as the artifact.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CPP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/packages/react-native-enriched-markdown/src/web/wasm}"

mkdir -p "$OUT_DIR"

# Intermediates stay out of the source tree: a failed link used to leave
# enrmrkd.o sitting next to the bundle.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Building md4c WASM…"

# Compile the C file separately (no -std=c++17)
emcc \
  -I "$CPP_ROOT" \
  -O2 \
  -c "$CPP_ROOT/enrmrkd/enrmrkd.c" \
  -o "$WORK/enrmrkd.o"

# Compile C++ sources and link everything together. em++, not emcc: emscripten
# 6.0.6 turned DEFAULT_TO_CXX off, so emcc no longer links the C++ runtime.
em++ \
  "$SCRIPT_DIR/md4c_wasm.cpp" \
  "$SCRIPT_DIR/ASTSerializer.cpp" \
  "$CPP_ROOT/parser/MD4CParser.cpp" \
  "$WORK/enrmrkd.o" \
  -I "$CPP_ROOT" \
  -I "$CPP_ROOT/enrmrkd" \
  -I "$SCRIPT_DIR" \
  -O2 \
  -std=c++17 \
  -Wswitch \
  -s WASM=1 \
  -s SINGLE_FILE=1 \
  -s EXPORTED_FUNCTIONS='["_parseMarkdown"]' \
  -s EXPORTED_RUNTIME_METHODS='["ccall","cwrap","UTF8ToString"]' \
  -s ENVIRONMENT='web' \
  -s MODULARIZE=1 \
  -s EXPORT_NAME='createMd4cModule' \
  -s STACK_SIZE=8MB \
  -s INITIAL_MEMORY=16MB \
  -s MAXIMUM_MEMORY=512MB \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s GROWABLE_ARRAYBUFFERS=0 \
  -o "$OUT_DIR/md4c.js"

echo "Done → $OUT_DIR/md4c.js"
