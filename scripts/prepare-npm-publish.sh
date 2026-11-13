#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RN_PKG="$REPO_ROOT/packages/react-native-enriched-markdown"
CORE_CPP="$REPO_ROOT/packages/core/cpp"
ANDROID_LIB="$REPO_ROOT/packages/enriched-markdown-android"
# Kotlin sources the RN Android module compiles from the standalone Android library;
# see the manifest and android/build.gradle.
SHARED_SOURCES_MANIFEST="$RN_PKG/android/shared-sources.txt"
SHARED_SOURCES_DIR="$RN_PKG/android/shared-sources"

mode="${1:-}"

case "$mode" in
  prepack)
    if [[ ! -d "$CORE_CPP" ]]; then
      echo "[react-native-enriched-markdown] error: core cpp directory not found at $CORE_CPP" >&2
      exit 1
    fi

    # Restore the full vendor tree so the generated registry (which inlines
    # highlight queries) is up to date. The registry is small and ships in the
    # tarball; the heavy grammar sources and runtime are excluded (downloaded
    # by postinstall.mjs on the consumer's machine).
    node "$REPO_ROOT/vendor/vendor-grammars.mjs"

    # Restore RaTeX so we can verify the vendor tree is healthy, but its
    # contents are excluded from the tarball (downloaded by postinstall.mjs).
    node "$REPO_ROOT/vendor/vendor-ratex.mjs"

    if [[ ! -f "$SHARED_SOURCES_MANIFEST" ]]; then
      echo "[react-native-enriched-markdown] error: shared sources manifest not found at $SHARED_SOURCES_MANIFEST" >&2
      exit 1
    fi

    cd "$RN_PKG"
    rm -rf cpp
    mkdir -p cpp
    cp -R "$CORE_CPP/." cpp/

    # Ship the registry codegen + manifest alongside the vendored grammars so a
    # published consumer can compile a custom language set (the default set uses
    # the restored cpp/highlight/vendor/generated registry and needs neither).
    cp "$REPO_ROOT/vendor/gen-registry.mjs" cpp/highlight/gen-registry.mjs
    cp "$REPO_ROOT/vendor/grammar-versions.json" cpp/highlight/grammar-versions.json

    # Remove the heavy vendored content from the copy — these are downloaded by
    # the postinstall script on the consumer's machine from the npm registry.
    # Keep vendor/generated/ and vendor/generated-custom/ (small, pre-built registries).
    rm -rf cpp/highlight/vendor/grammars
    rm -rf cpp/highlight/vendor/tree-sitter

    # RaTeX vendor tree (ios/vendor) is excluded from the tarball by the
    # "!ios/vendor" entry in package.json's "files" array — no need to delete it.

    # Materialize the Kotlin sources shared with the standalone Android library.
    # In the monorepo android/build.gradle compiles them from
    # packages/enriched-markdown-android; the tarball ships a copy of exactly the
    # files listed in the manifest, laid out as in the library, which build.gradle
    # resolves first.
    rm -rf "$SHARED_SOURCES_DIR"
    while IFS= read -r entry || [[ -n "$entry" ]]; do
      entry="${entry#"${entry%%[![:space:]]*}"}"
      entry="${entry%"${entry##*[![:space:]]}"}"
      if [[ -z "$entry" || "$entry" == \#* ]]; then
        continue
      fi
      if [[ ! -f "$ANDROID_LIB/$entry" ]]; then
        echo "[react-native-enriched-markdown] error: shared source $entry listed in $SHARED_SOURCES_MANIFEST not found in $ANDROID_LIB" >&2
        exit 1
      fi
      mkdir -p "$SHARED_SOURCES_DIR/$(dirname "$entry")"
      cp "$ANDROID_LIB/$entry" "$SHARED_SOURCES_DIR/$entry"
    done < "$SHARED_SOURCES_MANIFEST"

    # Ship the RaTeX manifest so postinstall.mjs can fetch it.
    cp "$REPO_ROOT/vendor/ratex-version.json" ratex-version.json

    # Ship the vendor scripts so postinstall.mjs can invoke them in consumer mode.
    cp "$REPO_ROOT/vendor/vendor-grammars.mjs" vendor-grammars.mjs
    cp "$REPO_ROOT/vendor/vendor-ratex.mjs" vendor-ratex.mjs

    cp "$REPO_ROOT/LICENSE" LICENSE
    ;;
  postpack)
    cd "$RN_PKG"
    rm -rf cpp
    ln -s ../core/cpp cpp

    rm -rf "$SHARED_SOURCES_DIR"

    rm -f LICENSE ratex-version.json vendor-grammars.mjs vendor-ratex.mjs
    ;;
  *)
    echo "[react-native-enriched-markdown] usage: $0 prepack|postpack" >&2
    exit 1
    ;;
esac
