#!/bin/bash
set -euo pipefail

# Software Mansion's MD4C fork, not upstream mity/md4c: it renames everything
# the parser exposes to an ENRMRKD_/enrmrkd_ prefix so an application can embed
# Enriched alongside another copy of MD4C without duplicate symbols or ambiguous
# `md4c.h` lookups (#846). Upstream changes reach us by merging into that fork.
REPO="software-mansion-labs/md4c"
BRANCH="master"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/src"
DEST_DIR="$(cd "$(dirname "$0")/.." && pwd)/packages/core/cpp/enrmrkd"

FILES=(
  "enrmrkd.c"
  "enrmrkd.h"
)

echo "Fetching parser sources from github.com/${REPO} (branch: ${BRANCH})..."

mkdir -p "$DEST_DIR"

for file in "${FILES[@]}"; do
  url="${BASE_URL}/${file}"
  dest="${DEST_DIR}/${file}"
  echo "  ${url} -> ${dest}"
  curl -fSL --retry 3 "$url" -o "$dest"
done

echo "Done. Files updated in ${DEST_DIR}"
