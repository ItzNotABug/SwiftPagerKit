#!/usr/bin/env bash
set -Eeuo pipefail

# Print the newest available iPhone simulator UDID.
xcrun simctl list devices available --json | python3 -c '
import json
import re
import sys

try:
    payload = json.load(sys.stdin)
except Exception:
    sys.exit(1)

candidates = []
for runtime, devices in payload.get("devices", {}).items():
    match = re.search(r"iOS[- ]([0-9]+)(?:[-.]([0-9]+))?", runtime)
    if not match:
        continue

    major = int(match.group(1))
    minor = int(match.group(2) or 0)
    for device in devices:
        name = device.get("name", "")
        udid = device.get("udid", "")
        if not device.get("isAvailable", True) or not name.startswith("iPhone") or not udid:
            continue

        # Prefer mainstream phones over SE-style small screens when versions tie.
        family_score = 0 if "SE" in name else 1
        candidates.append(((major, minor, family_score, name), udid))

if not candidates:
    sys.exit(1)

candidates.sort(reverse=True)
print(candidates[0][1])
' || xcrun simctl list devices available | awk -F '[()]' '/iPhone/ { print $2; exit }'
