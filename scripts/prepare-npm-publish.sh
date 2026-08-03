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
      echo "error: core cpp directory not found at $CORE_CPP" >&2
      exit 1
    fi

    # Grammar sources are gitignored (see .gitignore); restore them from the
    # grammar devDependencies so the published tarball ships the full vendored
    # set. No-op when already up to date (stamp guard).
    node "$REPO_ROOT/vendor/vendor-grammars.mjs" --grammars-only

    cd "$RN_PKG"
    rm -rf cpp
    mkdir -p cpp
    cp -R "$CORE_CPP/." cpp/

    # Ship the registry codegen + manifest alongside the vendored grammars so a
    # published consumer can compile a custom language set (the default set uses
    # the committed cpp/highlight/vendor/generated registry and needs neither).
    cp "$REPO_ROOT/vendor/gen-registry.mjs" cpp/highlight/gen-registry.mjs
    cp "$REPO_ROOT/vendor/grammar-versions.json" cpp/highlight/grammar-versions.json

    cp "$REPO_ROOT/README.md" README.md
    cp "$REPO_ROOT/LICENSE" LICENSE
    cp -R "$REPO_ROOT/docs" docs
    ;;
  postpack)
    cd "$RN_PKG"
    rm -rf cpp
    ln -s ../core/cpp cpp

    rm -f README.md LICENSE
    rm -rf docs
    ;;
  *)
    echo "usage: $0 prepack|postpack" >&2
    exit 1
    ;;
esac
