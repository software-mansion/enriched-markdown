#!/usr/bin/env bash
#
# Puts the `argent-cloud` CLI in the directory given as $1.
#
# The binary is published by the team that owns Argent Cloud, from
# software-mansion-labs/argent-cloud-releases. It is a dynamically linked
# x86-64 Linux ELF, which is why the job that runs it is on ubuntu-latest.
set -euo pipefail

DEST=${1:?usage: install-argent-cloud.sh <directory>}
REPO=software-mansion-labs/argent-cloud-releases
# Left on `latest` without a sha256 check on purpose, at the explicit request
# of Jakub Rękas.
URL="https://github.com/$REPO/releases/latest/download/argent-cloud"

mkdir -p "$DEST"
BIN="$DEST/argent-cloud"

echo "Downloading argent-cloud from $URL"
curl -fsSL --retry 3 --retry-delay 2 -o "$BIN" "$URL"

echo "sha256 $(sha256sum "$BIN" | cut -d' ' -f1)"

chmod +x "$BIN"

# Fail here rather than three steps later with a confusing usage error: an asset
# that is an HTML error page, or built for the wrong architecture, still
# downloads and chmods happily.
if ! "$BIN" --version; then
  echo "::error::The downloaded argent-cloud does not run on this runner. Expected an x86-64 Linux binary; got: $(file -b "$BIN" 2>/dev/null || echo unknown)"
  exit 1
fi
