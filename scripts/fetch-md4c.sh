#!/bin/bash
set -euo pipefail

REPO="mity/md4c"
BRANCH="master"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/src"
DEST_DIR="$(cd "$(dirname "$0")/.." && pwd)/packages/core/cpp/md4c"

FILES=(
  "md4c.c"
  "md4c.h"
  "entity.c"
  "entity.h"
)

echo "Fetching md4c sources from github.com/${REPO} (branch: ${BRANCH})..."

mkdir -p "$DEST_DIR"

for file in "${FILES[@]}"; do
  url="${BASE_URL}/${file}"
  dest="${DEST_DIR}/${file}"
  echo "  ${url} -> ${dest}"
  curl -fSL --retry 3 "$url" -o "$dest"
done

echo "Done. Files updated in ${DEST_DIR}"
