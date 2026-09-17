#!/bin/bash
# PROPOSAL SHOTS for issue #175 — runs only Proposal175ScreenshotTests and
# exports the PNGs to proposals/175-shooting-percentages/.
#
# Same shape as scripts/screenshots.sh (resolve the simulator by name up front,
# fail loudly if it doesn't exist) but scoped to the proposal's own test class
# so it doesn't re-run the whole merge-gate suite.
#
# Usage: scripts/proposal-175-shots.sh ["iPhone 14 Plus"] [test method]
set -euo pipefail

SIM="${1:-iPhone 14 Plus}"
ONLY="${2:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULT="$(mktemp -d)/proposal175.xcresult"
OUT="$ROOT/proposals/175-shooting-percentages"

UDID="$(xcrun simctl list devices available \
        | sed -n "s/^ *${SIM} (\([0-9A-F-]*\)) .*/\1/p" | head -1)"
if [ -z "$UDID" ]; then
  echo "✗ No available simulator named '$SIM'. Installed:" >&2
  xcrun simctl list devices available | grep -E "^ +iPhone" >&2
  exit 1
fi

TARGET="CourtsideHoopStatsUITests/Proposal175ScreenshotTests"
[ -n "$ONLY" ] && TARGET="$TARGET/$ONLY"

echo "▶︎ Proposal #175 shots on '$SIM' ($UDID) — $TARGET"
xcodebuild test \
  -project "$ROOT/CourtsideHoopStats.xcodeproj" \
  -scheme CourtsideHoopStats \
  -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:"$TARGET" \
  -resultBundlePath "$RESULT" \
  > "$RESULT.log" 2>&1 || { tail -40 "$RESULT.log"; echo "✗ see $RESULT.log"; exit 1; }

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
        name = a["suggestedHumanReadableName"]
        if not name or not name[0].isdigit():
            continue
        clean = name.split("_")[0] + ".png"
        shutil.copy(os.path.join(tmp, a["exportedFileName"]), os.path.join(out, clean))
        print("  wrote " + clean)
PY

echo "✓ $OUT"
