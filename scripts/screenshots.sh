#!/bin/bash
# Capture app screenshots via the XCUITest screenshot harness and export the
# PNGs to screenshots/. Serves README imagery and App Store listing shots.
#
# Usage: scripts/screenshots.sh [simulator name]
#   scripts/screenshots.sh                     # iPhone 17 Pro (default)
#   scripts/screenshots.sh "iPhone 17 Pro Max" # App Store 6.9" size
set -euo pipefail

SIM="${1:-iPhone 17 Pro}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULT="$(mktemp -d)/screenshots.xcresult"
OUT="$ROOT/screenshots"

echo "▶︎ Running screenshot UI tests on '$SIM'…"
xcodebuild test \
  -project "$ROOT/CourtsideHoopStats.xcodeproj" \
  -scheme CourtsideHoopStats \
  -destination "platform=iOS Simulator,name=$SIM" \
  -only-testing:CourtsideHoopStatsUITests \
  -resultBundlePath "$RESULT" \
  >/dev/null

echo "▶︎ Exporting attachments…"
TMP="$(mktemp -d)"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$TMP" >/dev/null

mkdir -p "$OUT"
python3 - "$TMP" "$OUT" <<'PY'
import json, os, shutil, sys
tmp, out = sys.argv[1], sys.argv[2]
m = json.load(open(os.path.join(tmp, "manifest.json")))
for entry in m:
    for a in entry.get("attachments", []):
        # Keep only our named screenshots (NN-name), drop the debug ones.
        name = a["suggestedHumanReadableName"]
        if not name or not name[0].isdigit():
            continue
        clean = name.split("_")[0] + ".png"
        shutil.copy(os.path.join(tmp, a["exportedFileName"]), os.path.join(out, clean))
        print("  wrote screenshots/" + clean)
PY

echo "✓ Screenshots in $OUT"
