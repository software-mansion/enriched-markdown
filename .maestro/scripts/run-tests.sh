#!/bin/bash

# run-tests.sh - script to set up device, build example app, and run Maestro flows.
#
# Usage:
#   ./run-tests.sh --platform <ios|android> [--config <file>] [--update-screenshots] [--rebuild] [--include-tags <tags>] [--exclude-tags <tags>] [flows]
#
# Opts:
#   --platform            Required. Target platform, either ios or android.
#
#   --app                 Which app to test: rn (default), android-native, or ios-native.
#
#   --config              Path to a Maestro config.yaml to use for tag filtering and
#                           flow discovery. When set, defaults to the enrichedMarkdownText
#                           workspace root if no explicit flows are given.
#                           Pre-built configs in .maestro/:
#                             config.yaml          – all tests
#                             config-smoke.yaml    – smoke tag only
#                             config-advanced.yaml – advanced tag only
#
#   --update-screenshots  Instead of running tests, refresh baselines.
#
#   --rebuild             Force a rebuild and install, even if the app is already
#                           installed on the device.
#
#   --include-tags        Comma-separated tags to include (passed to maestro as-is).
#
#   --exclude-tags        Comma-separated tags to exclude. Merged with the automatic
#                           platform exclusion (ios-only / android-only).
#
#   flows                 One or more Maestro flow files (or directories) to run.
#                           Defaults to all component suites if omitted.
#
# Examples:
#   ./run-tests.sh --platform ios .maestro/enrichedMarkdownText/flows
#   ./run-tests.sh --platform android --update-screenshots --rebuild
#   ./run-tests.sh --platform ios --config .maestro/config-smoke.yaml
#   ./run-tests.sh --platform ios --include-tags block
#   ./run-tests.sh --platform ios --include-tags smoke --exclude-tags image,header

set -euo pipefail

MIN_MAESTRO_VERSION="2.5.0"

if ! command -v maestro >/dev/null 2>&1; then
  echo "Error, maestro CLI not found." >&2
  exit 1
fi

MAESTRO_VERSION=$(maestro --version)
# Compare versions by sorting them; if the minimum sorts after the actual, it's too old.
# flags: -V (version sort) -C (check mode) so no need to check via head
if ! printf '%s\n%s\n' "$MIN_MAESTRO_VERSION" "$MAESTRO_VERSION" | sort -VC; then
  echo "Error: maestro $MAESTRO_VERSION is too old, minimum required is $MIN_MAESTRO_VERSION" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MAESTRO_ROOT="$REPO_ROOT/.maestro"
SCREENSHOT_ROOT="$MAESTRO_ROOT"
BUNDLE_ID="swmansion.enriched.markdown.example"
APP="rn"

PLATFORM=""
CONFIG_FILE=""
INCLUDE_TAGS=""
EXCLUDE_TAGS=""
UPDATE_SCREENSHOTS=""
REBUILD=""
FLOWS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --platform)           PLATFORM="$2"; shift 2 ;;
    --app)                APP="$2"; shift 2 ;;
    --config)             CONFIG_FILE="$2"; shift 2 ;;
    --include-tags)       INCLUDE_TAGS="$2"; shift 2 ;;
    --exclude-tags)       EXCLUDE_TAGS="$2"; shift 2 ;;
    --update-screenshots) UPDATE_SCREENSHOTS="true"; shift ;;
    --rebuild)            REBUILD="true"; shift ;;
    *)                    FLOWS="${FLOWS:+$FLOWS }$1"; shift ;;
  esac
done

if [ -z "$FLOWS" ]; then
  if [ -n "$CONFIG_FILE" ]; then
    FLOWS="$MAESTRO_ROOT"
  elif [ "$APP" = "android-native" ]; then
    FLOWS="$MAESTRO_ROOT/androidExample/enrichedMarkdownText/flows"
  elif [ "$APP" = "ios-native" ]; then
    FLOWS="$MAESTRO_ROOT/iosExample/enrichedMarkdownText/flows"
  else
    FLOWS=$(find "$MAESTRO_ROOT/enrichedMarkdownText/flows" "$MAESTRO_ROOT/enrichedMarkdownInput/flows" -name "*.yaml" -exec dirname {} \; 2>/dev/null | sort -u | tr '\n' ' ')
  fi
fi

case "$APP" in
  rn)
    BUNDLE_ID="swmansion.enriched.markdown.example"
    ;;
  android-native)
    BUNDLE_ID="swmansion.enriched.markdown.android.example"
    if [ "$PLATFORM" != android ]; then
      echo "Error: --app android-native requires --platform android" >&2
      exit 1
    fi
    ;;
  ios-native)
    BUNDLE_ID="swmansion.enriched.markdown.ios.example"
    if [ "$PLATFORM" != ios ]; then
      echo "Error: --app ios-native requires --platform ios" >&2
      exit 1
    fi
    ;;
  *)
    echo "Error: unknown --app value '$APP'. Use rn, android-native, or ios-native." >&2
    exit 1
    ;;
esac

case "$PLATFORM" in
  ios)      SETUP="$SCRIPT_DIR/setup-ios-simulator.sh" ;;
  android)  SETUP="$SCRIPT_DIR/setup-android-emulator.sh" ;;
  *)        echo "Error: --platform is required. (--platform <ios|android>)" >&2; exit 1 ;;
esac

SETUP_OUTPUT=$("$SETUP" 2>&1)
echo "$SETUP_OUTPUT"
DEVICE_ID=$(echo "$SETUP_OUTPUT" | grep "^DEVICE_ID=" | cut -d= -f2)

shutdown_device() {
  if [ "$PLATFORM" = ios ]; then
    xcrun simctl shutdown "$DEVICE_ID" 2>/dev/null || true
  else
    adb -s "$DEVICE_ID" emu kill 2>/dev/null || true
  fi
}
trap shutdown_device EXIT

app_installed() {
  if [ "$PLATFORM" = ios ]; then
    xcrun simctl listapps "$DEVICE_ID" 2>/dev/null | grep -q "$BUNDLE_ID"
  else
    adb -s "$DEVICE_ID" shell pm list packages "$BUNDLE_ID" 2>/dev/null | grep -q "$BUNDLE_ID"
  fi
}

if [ -n "$REBUILD" ] || ! app_installed; then
  [ -n "$REBUILD" ] && echo "=== rebuild forced, building and installing ==="
  [ -z "$REBUILD" ] && echo "=== App ($BUNDLE_ID) not found, building and installing ==="
  if [ "$APP" = "android-native" ]; then
    ANDROID_SERIAL="$DEVICE_ID" yarn android-example build
    adb -s "$DEVICE_ID" install -r "$REPO_ROOT/apps/android-example/app/build/outputs/apk/debug/app-debug.apk"
  elif [ "$APP" = "ios-native" ]; then
    IOS_SIMULATOR_UDID="$DEVICE_ID" yarn ios-example build
    IOS_APP=$(find "$REPO_ROOT/apps/ios-example/build" -name 'EnrichedMarkdownExample.app' -path '*Debug-iphonesimulator*' | head -1)
    if [ -z "$IOS_APP" ]; then
      echo "Error: EnrichedMarkdownExample.app not found after build" >&2
      exit 1
    fi
    xcrun simctl install "$DEVICE_ID" "$IOS_APP"
  elif [ "$PLATFORM" = ios ]; then
    yarn react-native-example ios --udid "$DEVICE_ID"
  else
    yarn react-native-example android --device "$DEVICE_ID"
  fi
else
  echo "=== APP ($BUNDLE_ID) aleady installed, skipping build ==="
fi

EXTRA_FLAGS="--env SCREENSHOT_ROOT=$SCREENSHOT_ROOT"
[ -n "$UPDATE_SCREENSHOTS" ] && EXTRA_FLAGS="$EXTRA_FLAGS --env UPDATE_SCREENSHOTS=true"
[ -n "$CONFIG_FILE" ]        && EXTRA_FLAGS="$EXTRA_FLAGS --config $CONFIG_FILE"
[ -n "$INCLUDE_TAGS" ]       && EXTRA_FLAGS="$EXTRA_FLAGS --include-tags $INCLUDE_TAGS"
# Exclude platform-specific tests for other platform, merged with any user exclusions
case "$PLATFORM" in
  ios)      EXTRA_FLAGS="$EXTRA_FLAGS --exclude-tags ${EXCLUDE_TAGS:+$EXCLUDE_TAGS,}android-only" ;;
  android)  EXTRA_FLAGS="$EXTRA_FLAGS --exclude-tags ${EXCLUDE_TAGS:+$EXCLUDE_TAGS,}ios-only" ;;
esac

# Maestro resolves addMedia paths by walking the workspace inputs. Since assets
# live outside the flows directory, always include it so media files are found.
ASSETS_DIR="$MAESTRO_ROOT/assets"
[ -d "$ASSETS_DIR" ] && FLOWS="$ASSETS_DIR $FLOWS"

echo "=== Running maestro tests ==="
# shellcheck disable=SC2086
maestro test --device "$DEVICE_ID" $EXTRA_FLAGS $FLOWS

