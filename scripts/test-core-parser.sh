#!/bin/bash
#
# Host-compiled checks for packages/core/cpp. These catch two things the native
# iOS/Android builds cannot see:
#
#   * the vendored parser's output moving. It is synced from our MD4C fork by
#     fetch-md4c.sh, so every sync can change how a document parses; the golden
#     AST dump below makes that a reviewable diff instead of a surprise.
#   * a global symbol or a public name that would collide with another embedded
#     MD4C copy in the same application (#846).
#
# Usage:
#   scripts/test-core-parser.sh             verify
#   scripts/test-core-parser.sh --update    rewrite the golden AST dump
#
# The last check downloads upstream MD4C, and a failed download fails the run.
# Outside CI, ENRM_SKIP_COEXISTENCE_CHECK=1 lets an offline run skip just that.
#
set -euo pipefail

# The golden dump records the fixtures in glob order, and the symbol listing is
# sorted; both must collate the same way on every machine.
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CPP_ROOT="$REPO_ROOT/packages/core/cpp"
TESTS_DIR="$CPP_ROOT/tests"
GOLDEN="$TESTS_DIR/golden/ast.txt"

# Pinned: the coexistence check must not depend on upstream's moving master.
UPSTREAM_MD4C_REF="v0.6.0"

update=0
case "${1:-}" in
  --update) update=1 ;;
  "") ;;
  *) echo "usage: $0 [--update]" >&2; exit 2 ;;
esac

CC_BIN="${CC:-cc}"
CXX_BIN="${CXX:-c++}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Building the vendored parser and the AST dumper"
"$CC_BIN" -O1 -std=c99 -DENRMRKD_USE_UTF8=1 -c "$CPP_ROOT/enrmrkd/enrmrkd.c" -o "$WORK/enrmrkd.o"
"$CXX_BIN" -O1 -std=c++17 -Wall -I "$CPP_ROOT/enrmrkd" -I "$CPP_ROOT/parser" -I "$CPP_ROOT/wasm" \
  "$TESTS_DIR/ast_dump.cpp" \
  "$CPP_ROOT/parser/MD4CParser.cpp" \
  "$CPP_ROOT/wasm/ASTSerializer.cpp" \
  "$WORK/enrmrkd.o" -o "$WORK/ast-dump"

echo "==> Checking the vendored parser's exported symbols"
if command -v nm >/dev/null 2>&1; then
  # Some platforms (e.g. MacOS) prefix C symbols with an underscore.
  unexpected=$(nm -g --defined-only "$WORK/enrmrkd.o" \
               | awk 'NF >= 3 { print $3 }' | grep -vE '^_?enrmrkd_' | sort -u || true)
  if [ -n "$unexpected" ]; then
    echo "FAIL: the vendored parser defines globals without the enrmrkd_ prefix:" >&2
    echo "$unexpected" | sed 's/^/    /' >&2
    echo >&2
    echo "Each would collide with another embedded MD4C copy. They usually arrive" >&2
    echo "with a merge from upstream into software-mansion-labs/md4c; run that" >&2
    echo "repo's scripts/rename-upstream-symbols.pl and re-sync." >&2
    exit 1
  fi
  nm -g --defined-only "$WORK/enrmrkd.o" | awk 'NF >= 3 { print "    " $3 }' | sort -u
else
  echo "    nm not available, skipped"
fi

echo "==> Comparing the parsed AST against the golden dump"
shopt -s nullglob
fixtures=("$TESTS_DIR"/fixtures/*.md)
shopt -u nullglob
if [ "${#fixtures[@]}" -eq 0 ]; then
  echo "FAIL: no fixtures in ${TESTS_DIR#"$REPO_ROOT"/}/fixtures" >&2
  exit 1
fi
"$WORK/ast-dump" "${fixtures[@]}" > "$WORK/ast.txt"
if [ "$update" -eq 1 ]; then
  mv "$WORK/ast.txt" "$GOLDEN"
  echo "    golden dump updated: ${GOLDEN#"$REPO_ROOT"/}"
elif ! diff -u "$GOLDEN" "$WORK/ast.txt" > "$WORK/ast.diff"; then
  echo "FAIL: the AST changed for the fixture corpus:" >&2
  head -40 "$WORK/ast.diff" | cut -c1-200 >&2
  echo >&2
  echo "If the change is intended (a parser sync, or a MD4CParser change), review" >&2
  echo "it and re-record with: scripts/test-core-parser.sh --update" >&2
  exit 1
else
  echo "    $(grep -c '^=== ' "$GOLDEN") fixture/flag combinations unchanged"
fi

echo "==> Linking beside another embedded MD4C copy (mity/md4c $UPSTREAM_MD4C_REF)"
mkdir -p "$WORK/other"
base="https://raw.githubusercontent.com/mity/md4c/$UPSTREAM_MD4C_REF/src"
if ! curl -fsSL --retry 2 "$base/md4c.c" -o "$WORK/other/md4c.c" \
  || ! curl -fsSL --retry 2 "$base/md4c.h" -o "$WORK/other/md4c.h"; then
  if [ "${ENRM_SKIP_COEXISTENCE_CHECK:-0}" = "1" ] && [ -z "${CI:-}" ]; then
    echo "    could not fetch upstream MD4C; skipped by ENRM_SKIP_COEXISTENCE_CHECK"
    echo
    echo "PASS (coexistence check skipped)"
    exit 0
  fi
  echo "FAIL: could not fetch mity/md4c $UPSTREAM_MD4C_REF from $base" >&2
  echo >&2
  echo "The coexistence check is the regression guard for #846, so a download" >&2
  echo "failure is a failure, not a skip. Working offline, outside CI, you can" >&2
  echo "run the rest with ENRM_SKIP_COEXISTENCE_CHECK=1." >&2
  exit 1
fi
cat > "$WORK/coexist.cpp" <<'EOF'
/*
 * An application linking Enriched and another MD4C-embedding dependency.
 *
 * Both headers are included in this one translation unit, on purpose and in
 * this order: a vendored enrmrkd.h that re-introduced an MD_-prefixed name, or
 * whose include guard regressed to MD4C_H and so swallowed the second header,
 * must not compile. The link step below then covers the symbols.
 */
#include "enrmrkd.h"
extern "C" {
#include "other/md4c.h"
}
#include "MD4CParser.hpp"
#include <cstddef>
#include <iostream>
#include <string>
static int onBlock(MD_BLOCKTYPE, void *, void *) { return 0; }
static int onSpan(MD_SPANTYPE, void *, void *) { return 0; }
static int onText(MD_TEXTTYPE, const MD_CHAR *, MD_SIZE, void *) { return 0; }
static int onEnrmBlock(ENRMRKD_BLOCKTYPE, void *, void *) { return 0; }
static int onEnrmSpan(ENRMRKD_SPANTYPE, void *, void *) { return 0; }
static int onEnrmText(ENRMRKD_TEXTTYPE, const ENRMRKD_CHAR *, ENRMRKD_SIZE, void *) { return 0; }
int main() {
  const std::string doc = "# hi *there* ||spoiler||\n";
  const auto root = Markdown::MD4CParser().parse(doc, Markdown::Md4cFlags{}, true);
  MD_PARSER other{0, MD_DIALECT_GITHUB, onBlock, onBlock, onSpan, onSpan, onText, nullptr, nullptr};
  const int rc = md_parse(doc.c_str(), (MD_SIZE)doc.size(), &other, nullptr);
  ENRMRKD_PARSER ours{0,          ENRMRKD_DIALECT_GITHUB,
                      onEnrmBlock, onEnrmBlock,
                      onEnrmSpan,  onEnrmSpan,
                      onEnrmText,  nullptr,
                      nullptr};
  const int ourRc = enrmrkd_parse(doc.c_str(), (ENRMRKD_SIZE)doc.size(), &ours, nullptr);
  if (!root || rc != 0 || ourRc != 0) {
    std::cerr << "coexistence check failed: root=" << (root ? "ok" : "null") << " rc=" << rc
              << " ourRc=" << ourRc << "\n";
    return 1;
  }
  return 0;
}
EOF
"$CC_BIN" -O1 -std=c99 -c "$WORK/other/md4c.c" -o "$WORK/other.o"
"$CXX_BIN" -O1 -std=c++17 -I "$CPP_ROOT/enrmrkd" -I "$CPP_ROOT/parser" -I "$WORK" \
  -DENRMRKD_USE_UTF8=1 -c "$WORK/coexist.cpp" -o "$WORK/coexist.o"
"$CXX_BIN" -O1 -std=c++17 -I "$CPP_ROOT/enrmrkd" -I "$CPP_ROOT/parser" -c "$CPP_ROOT/parser/MD4CParser.cpp" -o "$WORK/parser.o"
"$CXX_BIN" "$WORK/other.o" "$WORK/enrmrkd.o" "$WORK/parser.o" "$WORK/coexist.o" -o "$WORK/coexist"
"$WORK/coexist"
echo "    both parsers linked and ran in one binary"

echo
echo "PASS"
