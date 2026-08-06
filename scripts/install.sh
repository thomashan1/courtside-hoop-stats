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
# The build must be able to *stop* the install. Previously this piped into grep
# with `|| true`, which discarded xcodebuild's exit status entirely: a failed
# build fell through to the install step and pushed the previous .app, which
# then looked like a shipped fix that hadn't changed anything. Nothing below
# runs unless the build actually succeeded.
BUILD_LOG="$(mktemp)"
trap 'rm -f "$BUILD_LOG"' EXIT

if ! xcodebuild -project "$ROOT/CourtsideHoopStats.xcodeproj" -scheme CourtsideHoopStats \
     -destination "platform=iOS,id=$FIRST_ID" -configuration Debug \
     -allowProvisioningUpdates build >"$BUILD_LOG" 2>&1; then
  echo "✗ BUILD FAILED — nothing installed." >&2
  echo "  (The previous .app is still on disk; installing it would look like a" >&2
  echo "   working build that silently changed nothing.)" >&2
  grep -E "error:" "$BUILD_LOG" | head -20 >&2
  exit 1
fi

grep -E "warning:.*\.swift" "$BUILD_LOG" || true

APP=$(find ~/Library/Developer/Xcode/DerivedData/CourtsideHoopStats-*/Build/Products/Debug-iphoneos \
  -maxdepth 1 -name "*.app" | head -1)
[ -n "$APP" ] || { echo "✗ no .app found despite a successful build" >&2; exit 1; }

echo "▶︎ Built: $(stat -f '%Sm' -t '%H:%M:%S' "$APP/CourtsideHoopStats")  (now $(date '+%H:%M:%S'))"

failed=0
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
    failed=1
  fi
done

# Exit non-zero if any device missed the build, so a partial run can't be
# reported as a success.
exit "$failed"
