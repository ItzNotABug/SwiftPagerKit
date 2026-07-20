#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PACKAGE_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
WORKSPACE_PATH="$PACKAGE_DIR/Examples/SwiftPagerKitDemo/SwiftPagerKitDemo.xcworkspace"
DERIVED_DATA_PATH="$PACKAGE_DIR/.build/demo"
SIMULATOR_ID="${SIMULATOR_ID:-}"
SIMULATOR_NAME="${SIMULATOR_NAME:-}"
BUNDLE_ID="com.swiftpagerkit.demo"
APP_NAME="SwiftPagerKitDemo.app"

log() {
    printf '[demo] %s\n' "$*" >&2
}

if [[ ! -d "$WORKSPACE_PATH" ]]; then
    printf 'error: demo workspace missing at %s\n' "$WORKSPACE_PATH" >&2
    exit 1
fi

if [[ -z "$SIMULATOR_ID" && -n "$SIMULATOR_NAME" ]]; then
    SIMULATOR_ID="$(xcrun simctl list devices available | awk -F '[()]' -v name="$SIMULATOR_NAME" '$0 ~ name { print $2; exit }')"
fi

if [[ -z "$SIMULATOR_ID" ]]; then
    SIMULATOR_ID="$("$PACKAGE_DIR/scripts/test/simulator.sh")"
fi

if [[ -z "$SIMULATOR_ID" ]]; then
    printf 'error: no available iPhone simulator found\n' >&2
    exit 1
fi

log "booting simulator $SIMULATOR_ID"
xcrun simctl boot "$SIMULATOR_ID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIMULATOR_ID" -b >/dev/null

log "running demo feature and UI smoke tests"
xcodebuild \
    -quiet \
    -workspace "$WORKSPACE_PATH" \
    -scheme SwiftPagerKitDemo \
    -configuration Debug \
    -destination "id=$SIMULATOR_ID" \
    -derivedDataPath "$DERIVED_DATA_PATH/tests" \
    CODE_SIGNING_ALLOWED=NO \
    test

log "building and launching demo app"
xcodebuild \
    -quiet \
    -workspace "$WORKSPACE_PATH" \
    -scheme SwiftPagerKitDemo \
    -configuration Debug \
    -destination "id=$SIMULATOR_ID" \
    -derivedDataPath "$DERIVED_DATA_PATH/run" \
    CODE_SIGNING_ALLOWED=NO \
    build

APP_PATH="$(find "$DERIVED_DATA_PATH/run/Build/Products/Debug-iphonesimulator" -maxdepth 2 -name "$APP_NAME" -type d | head -n 1)"
if [[ -z "$APP_PATH" ]]; then
    printf 'error: built demo app not found under %s\n' "$DERIVED_DATA_PATH/run/Build/Products/Debug-iphonesimulator" >&2
    exit 1
fi

xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID" >/dev/null

log "stopping demo app"
xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true

log "demo runtime validation complete"
