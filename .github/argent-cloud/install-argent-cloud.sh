#!/usr/bin/env bash
#
# Puts the `argent-cloud` CLI in the directory given as $1.
#
# The binary is published by the team that owns Argent Cloud, from
# software-mansion-labs/argent-cloud-releases. It is a dynamically linked
# x86-64 Linux ELF, which is why the job that runs it is on ubuntu-latest.
#
# By default this follows the release channel's `latest` pointer, because the
# tool is early and moves quickly and we want its fixes without a chore. That
# means an unpinned binary runs with SIM_ROUTER_API_KEY and ANTHROPIC_API_KEY in
# its environment, which is only acceptable because the publisher is a Software
# Mansion repository. To pin instead, set both of these in the workflow and the
# download becomes reproducible and verified:
#
#   ARGENT_CLOUD_VERSION  a release tag, e.g. 202610090911
#   ARGENT_CLOUD_SHA256   that asset's sha256, e.g.
#                         2e34e6f7996c1b43ef17d78755ce11abe1e0a19edf2c53e9d805c0d4b7addc03
#
# Setting only the version pins without verifying; setting only the sha256
# verifies whatever `latest` happens to be, and fails the job when it moves.
set -euo pipefail

DEST=${1:?usage: install-argent-cloud.sh <directory>}
REPO=software-mansion-labs/argent-cloud-releases
VERSION=${ARGENT_CLOUD_VERSION:-}
EXPECTED=${ARGENT_CLOUD_SHA256:-}

mkdir -p "$DEST"
BIN="$DEST/argent-cloud"

if [[ -n "$VERSION" ]]; then
  URL="https://github.com/$REPO/releases/download/$VERSION/argent-cloud"
else
  URL="https://github.com/$REPO/releases/latest/download/argent-cloud"
fi

echo "Downloading argent-cloud from $URL"
curl -fsSL --retry 3 --retry-delay 2 -o "$BIN" "$URL"

ACTUAL=$(sha256sum "$BIN" | cut -d' ' -f1)
echo "sha256 $ACTUAL"

if [[ -n "$EXPECTED" && "$ACTUAL" != "$EXPECTED" ]]; then
  echo "::error::argent-cloud sha256 is $ACTUAL but ARGENT_CLOUD_SHA256 says $EXPECTED. Refusing to run a binary we did not expect."
  exit 1
fi

chmod +x "$BIN"

# Fail here rather than three steps later with a confusing usage error: an asset
# that is an HTML error page, or built for the wrong architecture, still
# downloads and chmods happily.
if ! "$BIN" --version; then
  echo "::error::The downloaded argent-cloud does not run on this runner. Expected an x86-64 Linux binary; got: $(file -b "$BIN" 2>/dev/null || echo unknown)"
  exit 1
fi
