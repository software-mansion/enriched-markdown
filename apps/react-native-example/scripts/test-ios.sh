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

# Lower bound on how many tests must actually run, counted from the library's
# XCTest sources. A passing xcodebuild says nothing about coverage on its own:
# the lane was green for a while with only the harness placeholder compiled,
# because an unregistered suite is silently skipped rather than failed. Counting
# "- (void)test" prototypes under-approximates (helper superclasses can add
# more), so this catches a suite dropping out without going stale on its own.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tests_dir="$script_dir/../../../packages/react-native-enriched-markdown/__tests__/ios"
expected=0
if [ -d "$tests_dir" ]; then
  while IFS= read -r file; do
    count=$(grep -cE '^[[:space:]]*-[[:space:]]*\(void\)test' "$file" || true)
    expected=$((expected + count))
  done < <(find "$tests_dir" -maxdepth 1 -type f \( -name '*.m' -o -name '*.mm' \))
fi

echo "Running iOS unit tests on simulator $udid"
echo "Expecting at least $expected library test(s) from $tests_dir"

# -quiet keeps the log readable: the app and every pod compile first, and their
# output buries everything else. It costs us the per-test lines - build errors
# and the names of failing tests still print, but the assertion text does not,
# so a red lane says which test failed and nothing about why. The result bundle
# below carries both that text and the count, which is why it is worth asking
# for rather than dropping -quiet and logging thousands of compile lines.
work=$(mktemp -d "${TMPDIR:-/tmp}/test-ios.XXXXXX")
trap 'rm -rf "$work"' EXIT
result_bundle="$work/result.xcresult"

set +e
xcodebuild test \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$udid" \
  -derivedDataPath ios/build \
  -resultBundlePath "$result_bundle" \
  -quiet \
  CODE_SIGNING_ALLOWED=NO
status=$?
set -e

# Empty when the build failed before any test ran; xcodebuild already said why.
summary=$(xcrun xcresulttool get test-results summary \
  --path "$result_bundle" --format json 2>/dev/null || true)

if [ -n "$summary" ]; then
  printf '%s' "$summary" | jq -r '
    .testFailures[]? | "FAILED \(.targetName)/\(.testName)\n        \(.failureText)"' >&2
fi

if [ "$status" -ne 0 ]; then
  exit "$status"
fi

executed=$(printf '%s' "$summary" | jq -r '.totalTestCount // 0')
executed=${executed:-0}

echo "Executed $executed test(s)"
if [ "$executed" -lt "$expected" ]; then
  echo "Expected at least $expected test(s) to run but only $executed did." >&2
  echo "A suite under $tests_dir compiled but did not run." >&2
  exit 1
fi
