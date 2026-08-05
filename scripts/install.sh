#!/bin/bash
# Build once and install to the paired physical iPhones.
#
# Usage: scripts/install.sh [thomas|jean|all]     (default: all)
#
# Both devices are registered to the same Apple Developer team, so one Debug
# build is signed for both — build once, install twice.
#
# Note: development-signed builds stop launching after ~7 days. Re-run this to
# refresh them.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BID="com.thomashan.CourtsideHoopStats"
TARGET="${1:-all}"

THOMAS="161AC4C8-88E5-5FDA-9DA5-4F062C23D6B5"
JEAN="AD793CF7-0739-509B-A6D2-33C490448B88"

case "$TARGET" in
  thomas) IDS=("$THOMAS");          NAMES=("Thomas") ;;
  jean)   IDS=("$JEAN");            NAMES=("Jean") ;;
  all)    IDS=("$THOMAS" "$JEAN");  NAMES=("Thomas" "Jean") ;;
  *) echo "usage: $0 [thomas|jean|all]" >&2; exit 2 ;;
esac

# Build against whichever device we're installing first; the resulting .app is
# signed for every device on the profile, so a second build would be wasted.
FIRST_ID="${IDS[0]}"

echo "▶︎ Building…"
xcodebuild -project "$ROOT/CourtsideHoopStats.xcodeproj" -scheme CourtsideHoopStats \
  -destination "platform=iOS,id=$FIRST_ID" -configuration Debug \
  -allowProvisioningUpdates build 2>&1 \
  | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED" || true

APP=$(find ~/Library/Developer/Xcode/DerivedData/CourtsideHoopStats-*/Build/Products/Debug-iphoneos \
  -maxdepth 1 -name "*.app" | head -1)
[ -n "$APP" ] || { echo "✗ no .app found — build failed"; exit 1; }

# Guard against installing a stale binary when the build silently failed.
echo "▶︎ Built: $(stat -f '%Sm' -t '%H:%M:%S' "$APP/CourtsideHoopStats")  (now $(date '+%H:%M:%S'))"

for i in "${!IDS[@]}"; do
  device_id="${IDS[$i]}"
  device_name="${NAMES[$i]}"
  echo "▶︎ Installing to ${device_name}…"
  if xcrun devicectl device install app --device "$device_id" "$APP" >/dev/null 2>&1; then
    if xcrun devicectl device process launch --device "$device_id" "$BID" >/dev/null 2>&1; then
      echo "  OK  ${device_name}: installed and launched"
    else
      echo "  OK  ${device_name}: installed (not launched — device may be locked)"
    fi
  else
    echo "  FAILED  ${device_name}: install failed (connected and unlocked?)"
  fi
done
