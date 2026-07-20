#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PACKAGE_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"

TEMPLATE_PATH="${SWIFTPAGERKIT_REMOTE_MANIFEST_TEMPLATE:-$PACKAGE_DIR/scripts/build/Package.swift.template}"
OUTPUT_PATH="${SWIFTPAGERKIT_REMOTE_MANIFEST_OUTPUT:-$PACKAGE_DIR/.build/release/Package.swift}"
REPOSITORY="${GITHUB_REPOSITORY:-ItzNotABug/SwiftPagerKit}"
ARTIFACT_NAME="${SWIFTPAGERKIT_BINARY_ARTIFACT_NAME:-SwiftPagerKitCore.xcframework.zip}"

usage() {
    printf 'Usage: %s <version> <checksum> [output-path]\n' "$(basename -- "$0")" >&2
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

VERSION="${1:-}"
CHECKSUM="${2:-}"
if [[ $# -ge 3 ]]; then
    OUTPUT_PATH="$3"
fi

[[ -n "$VERSION" ]] || { usage; fail "version is required"; }
[[ -n "$CHECKSUM" ]] || { usage; fail "checksum is required"; }
[[ -f "$TEMPLATE_PATH" ]] || fail "remote manifest template missing at $TEMPLATE_PATH"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z]+([.-][0-9A-Za-z]+)*)?$ ]]; then
    fail "version must look like 0.1.0 or 0.1.0-preview.1"
fi

if [[ ! "$CHECKSUM" =~ ^[0-9a-f]{64}$ ]]; then
    fail "checksum must be a 64-character lowercase hex string"
fi

if [[ ! "$REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    fail "repository must look like owner/name, got $REPOSITORY"
fi

if [[ "$ARTIFACT_NAME" != "SwiftPagerKitCore.xcframework.zip" ]]; then
    fail "unexpected artifact name: $ARTIFACT_NAME"
fi

mkdir -p "$(dirname -- "$OUTPUT_PATH")"

ARTIFACT_URL="https://github.com/$REPOSITORY/releases/download/$VERSION/$ARTIFACT_NAME"

sed \
    -e "s|https://github.com/ItzNotABug/SwiftPagerKit/releases/download/VERSION/SwiftPagerKitCore.xcframework.zip|$ARTIFACT_URL|g" \
    -e "s|REPLACE_WITH_SWIFT_PACKAGE_COMPUTE_CHECKSUM|$CHECKSUM|g" \
    "$TEMPLATE_PATH" > "$OUTPUT_PATH"

if grep -Eq 'VERSION|REPLACE_WITH_SWIFT_PACKAGE_COMPUTE_CHECKSUM' "$OUTPUT_PATH"; then
    fail "generated manifest still contains placeholders"
fi

printf '%s\n' "$OUTPUT_PATH"
