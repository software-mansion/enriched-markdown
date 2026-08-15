#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RN_PKG="$REPO_ROOT/packages/react-native-enriched-markdown"
CORE_CPP="$REPO_ROOT/packages/core/cpp"

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

    # Ship the RaTeX manifest so postinstall.mjs can fetch it.
    cp "$REPO_ROOT/vendor/ratex-version.json" ratex-version.json

    # Ship the vendor scripts so postinstall.mjs can invoke them in consumer mode.
    cp "$REPO_ROOT/vendor/vendor-grammars.mjs" vendor-grammars.mjs
    cp "$REPO_ROOT/vendor/vendor-ratex.mjs" vendor-ratex.mjs

    cp "$REPO_ROOT/LICENSE" LICENSE
    cp -R "$REPO_ROOT/docs" docs
    ;;
  postpack)
    cd "$RN_PKG"
    rm -rf cpp
    ln -s ../core/cpp cpp

    rm -f LICENSE ratex-version.json vendor-grammars.mjs vendor-ratex.mjs
    rm -rf docs
    ;;
  *)
    echo "[react-native-enriched-markdown] usage: $0 prepack|postpack" >&2
    exit 1
    ;;
esac
