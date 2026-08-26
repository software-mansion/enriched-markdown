#!/bin/bash
set -euo pipefail

DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17"
IOS_VERSION="26.5"
RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-$(echo "$IOS_VERSION" | tr '.' '-')"
RUNTIME_LABEL="iOS $IOS_VERSION"
DEVICE_NAME="iPhone17-iOS${IOS_VERSION}-Enriched-Markdown"

if ! xcrun simctl list runtimes | grep -q "$RUNTIME"; then
  echo "Error: $RUNTIME_LABEL runtime not found."
  echo "Install it in Xcode."
  exit 1
fi

if ! xcrun simctl list devices | grep -q "$DEVICE_NAME ("; then
  echo "Creating simulator '$DEVICE_NAME'..."
  xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE" "$RUNTIME"
fi

UDID=$(xcrun simctl list devices | grep "$DEVICE_NAME (" | head -1 | grep -oE '[A-F0-9-]{36}')

if [ -z "$UDID" ]; then
  echo "Error: Could not find UDID for '$DEVICE_NAME'"
  exit 1
fi

STATE=$(xcrun simctl list devices | grep "$UDID" | grep -oE '\(Booted\)|\(Shutdown\)' || true)
if [ "$STATE" != "(Booted)" ]; then
  echo "Booting '$DEVICE_NAME' ($UDID)..."
  xcrun simctl boot "$UDID"
  # `bootstatus -b` exits before the app registry is ready on some runtimes.
  # Polling listapps for a built-in app is better signal that SpringBoard is up.
  echo "Waiting for simulator to finish booting (max 20s)..."
  SECONDS=0
  until xcrun simctl listapps "$UDID" 2>/dev/null | grep -q "com.apple.Preferences"; do
    if (( SECONDS >= 20 )); then
      echo "Timed out waiting for SpringBoard; continuing to build step to unstick the simulator."
      break
    fi
    sleep 2
  done
fi

# Disable autocorrect/capitalization/spell-check so Maestro typing is deterministic.
PREFS_PLIST="$HOME/Library/Developer/CoreSimulator/Devices/$UDID/data/Library/Preferences/com.apple.Preferences.plist"
defaults write "$PREFS_PLIST" KeyboardAutocapitalization -bool false
defaults write "$PREFS_PLIST" KeyboardAutocorrection -bool false
defaults write "$PREFS_PLIST" KeyboardCheckSpelling -bool false
xcrun simctl spawn "$UDID" launchctl kickstart -k system/com.apple.SpringBoard 2>/dev/null || true

open -a Simulator

echo "Simulator ready: $DEVICE_NAME ($UDID)"
echo "DEVICE_ID=$UDID"
