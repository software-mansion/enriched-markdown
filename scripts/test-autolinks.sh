#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_output="$(mktemp -d)"
trap 'rm -rf "$test_output"' EXIT
core="$repo_root/packages/core/cpp"
"${CC:-cc}" -std=c11 -DMD4C_USE_UTF8=1 -I"$core/md4c" -c "$core/md4c/md4c.c" -o "$test_output/md4c.o"
"${CXX:-c++}" -std=c++17 -DMD4C_USE_UTF8=1 -I"$core/md4c" "$core/tests/AutolinksTest.cpp" "$test_output/md4c.o" -o "$test_output/autolinks"
"$test_output/autolinks"
