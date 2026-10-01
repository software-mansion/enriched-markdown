#!/usr/bin/env bash
# Runs the app-hosted iOS unit tests (EnrichedMarkdownExampleTests) on a
# simulator, resolving a concrete destination so it works without a pre-booted
# device. Order: $IOS_SIMULATOR_UDID (CI sets this) -> a booted simulator ->
# the first available iPhone simulator. xcodebuild boots a shut-down sim itself.
set -euo pipefail

SCHEME="EnrichedMarkdownExample"
WORKSPACE="ios/EnrichedMarkdownExample.xcworkspace"

udid="${IOS_SIMULATOR_UDID:-}"
if [ -z "$udid" ]; then
  udid=$(xcrun simctl list devices booted -j |
    jq -r '[.devices[][] | select(.name | test("iPhone|iPad"))][0].udid // empty')
fi
if [ -z "$udid" ]; then
  udid=$(xcrun simctl list devices available -j |
    jq -r '[.devices[][] | select(.name | startswith("iPhone"))][0].udid // empty')
fi
if [ -z "$udid" ]; then
  echo "No iOS Simulator found. Create one in Xcode or set IOS_SIMULATOR_UDID." >&2
  exit 1
fi

echo "Running iOS unit tests on simulator $udid"
# -quiet drops per-file build spam (the app + all pods compile first); test
# results, warnings, and failures are still printed.
exec xcodebuild test \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$udid" \
  -derivedDataPath ios/build \
  -quiet \
  CODE_SIGNING_ALLOWED=NO
