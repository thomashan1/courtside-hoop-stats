#!/bin/bash
# Build once and install to the paired physical iPhones.
#
# Usage: scripts/install.sh [thomas|jean|all]     (default: all)
#
# Both devices are registered to the same Apple Developer team, so one Debug
# build is signed for both — build once, install twice.
#
# The two phones are rarely home at the same time, so `all` means "whichever
# are reachable": absent devices are skipped, not treated as failures. The
# build targets `generic/platform=iOS` rather than a specific device, so it
# can't fail just because a phone is out of the house.
#
# Note: development-signed builds stop launching after ~7 days. Re-run this to
# refresh them.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BID="com.thomashan.CourtsideHoopStats"
TARGET="${1:-all}"

TMPDIR_DEV="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_DEV"' EXIT

THOMAS="161AC4C8-88E5-5FDA-9DA5-4F062C23D6B5"
JEAN="AD793CF7-0739-509B-A6D2-33C490448B88"

case "$TARGET" in
  thomas) IDS=("$THOMAS");          NAMES=("Thomas") ;;
  jean)   IDS=("$JEAN");            NAMES=("Jean") ;;
  all)    IDS=("$THOMAS" "$JEAN");  NAMES=("Thomas" "Jean") ;;
  *) echo "usage: $0 [thomas|jean|all]" >&2; exit 2 ;;
esac

# Which of the requested devices are actually reachable right now.
#
# `transportType` is the signal, not `tunnelState`: a phone sitting on the home
# Wi-Fi reports `localNetwork` with `tunnelState: disconnected`, because the
# tunnel is only established when something actually talks to it. Gating on
# `tunnelState == connected` skipped both phones while they were both home.
# When a phone is genuinely away, `transportType` is null.
#
# Pairing alone says nothing — `devicectl` lists paired-but-absent phones too.
xcrun devicectl list devices --json-output "$TMPDIR_DEV/devices.json" >/dev/null 2>&1 || true

reachable() {
  python3 - "$TMPDIR_DEV/devices.json" "$1" <<'PY'
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    sys.exit(1)
for d in devices:
    if d.get("identifier") == sys.argv[2]:
        props = d.get("connectionProperties", {})
        reachable = (props.get("transportType") is not None
                     or props.get("tunnelState") == "connected")
        sys.exit(0 if reachable else 1)
sys.exit(1)
PY
}

PRESENT_IDS=()
PRESENT_NAMES=()
ABSENT_NAMES=()
for i in "${!IDS[@]}"; do
  if reachable "${IDS[$i]}"; then
    PRESENT_IDS+=("${IDS[$i]}")
    PRESENT_NAMES+=("${NAMES[$i]}")
  else
    ABSENT_NAMES+=("${NAMES[$i]}")
  fi
done

if [ "${#ABSENT_NAMES[@]}" -gt 0 ]; then
  echo "▶︎ Not reachable, skipping: ${ABSENT_NAMES[*]}"
fi

if [ "${#PRESENT_IDS[@]}" -eq 0 ]; then
  echo "✗ None of the requested devices are reachable — nothing to install." >&2
  echo "  Connect a phone (unlocked, trusted) and re-run." >&2
  exit 1
fi

echo "▶︎ Building for: ${PRESENT_NAMES[*]}"
# The build must be able to *stop* the install. Previously this piped into grep
# with `|| true`, which discarded xcodebuild's exit status entirely: a failed
# build fell through to the install step and pushed the previous .app, which
# then looked like a shipped fix that hadn't changed anything. Nothing below
# runs unless the build actually succeeded.
BUILD_LOG="$TMPDIR_DEV/build.log"

# `generic/platform=iOS` rather than a specific device: the .app is signed for
# every device on the profile anyway, and targeting one by id meant the build
# failed outright whenever that particular phone was away — taking the other
# phone's install down with it.
if ! xcodebuild -project "$ROOT/CourtsideHoopStats.xcodeproj" -scheme CourtsideHoopStats \
     -destination "generic/platform=iOS" -configuration Debug \
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
for i in "${!PRESENT_IDS[@]}"; do
  device_id="${PRESENT_IDS[$i]}"
  device_name="${PRESENT_NAMES[$i]}"
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

# Non-zero only if a device that *was* reachable failed to take the build. A
# phone that simply isn't home was already reported as skipped above and isn't
# an error — but a failure on one that is here must not be reported as success.
exit "$failed"
