#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PACKAGE_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
WORKSPACE_PATH="$PACKAGE_DIR/Examples/SwiftPagerKitDemo/SwiftPagerKitDemo.xcworkspace"
DERIVED_DATA_PATH="$PACKAGE_DIR/.build/demo"
SIMULATOR_ID="${SIMULATOR_ID:-}"
SIMULATOR_NAME="${SIMULATOR_NAME:-}"
SIMULATOR_ARCH="${SIMULATOR_ARCH:-$(uname -m)}"
DEMO_TEST_TIMEOUT_SECONDS="${DEMO_TEST_TIMEOUT_SECONDS:-900}"
DEMO_BUILD_TIMEOUT_SECONDS="${DEMO_BUILD_TIMEOUT_SECONDS:-600}"
RUN_DEMO_INSTALL_SMOKE="${RUN_DEMO_INSTALL_SMOKE:-0}"
BUNDLE_ID="com.swiftpagerkit.demo"
APP_NAME="SwiftPagerKitDemo.app"

log() {
    printf '[demo] %s\n' "$*" >&2
}

run_with_timeout() {
    local timeout_seconds="$1"
    shift

    python3 - "$timeout_seconds" "$@" <<'PY'
import os
import signal
import subprocess
import sys

timeout_seconds = float(sys.argv[1])
command = sys.argv[2:]

process = subprocess.Popen(command, start_new_session=True)
try:
    raise SystemExit(process.wait(timeout=timeout_seconds))
except subprocess.TimeoutExpired:
    print(f"error: command timed out after {timeout_seconds:g}s: {' '.join(command)}", file=sys.stderr)
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
    raise SystemExit(124)
PY
}

run_step() {
    local label="$1"
    shift
    local started_at ended_at elapsed

    started_at="$(date +%s)"
    log "$label"
    "$@"
    ended_at="$(date +%s)"
    elapsed=$((ended_at - started_at))
    log "$label complete in ${elapsed}s"
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

DESTINATION="platform=iOS Simulator,id=$SIMULATOR_ID,arch=$SIMULATOR_ARCH"

run_step "running demo feature and UI smoke tests" \
    run_with_timeout "$DEMO_TEST_TIMEOUT_SECONDS" \
    xcodebuild \
        -quiet \
        -workspace "$WORKSPACE_PATH" \
        -scheme SwiftPagerKitDemo \
        -configuration Debug \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        COMPILER_INDEX_STORE_ENABLE=NO \
        CODE_SIGNING_ALLOWED=NO \
        test

if [[ "$RUN_DEMO_INSTALL_SMOKE" != "1" ]]; then
    log "demo runtime validation complete"
    exit 0
fi

run_step "building demo app for install smoke" \
    run_with_timeout "$DEMO_BUILD_TIMEOUT_SECONDS" \
    xcodebuild \
        -quiet \
        -workspace "$WORKSPACE_PATH" \
        -scheme SwiftPagerKitDemo \
        -configuration Debug \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        COMPILER_INDEX_STORE_ENABLE=NO \
        CODE_SIGNING_ALLOWED=NO \
        build

APP_PATH="$(find "$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator" -maxdepth 2 -name "$APP_NAME" -type d | head -n 1)"
if [[ -z "$APP_PATH" ]]; then
    printf 'error: built demo app not found under %s\n' "$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator" >&2
    exit 1
fi

xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID" >/dev/null

log "stopping demo app"
xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true

log "demo runtime validation complete"
