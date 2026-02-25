#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------
# Android Health Check Script (ADB + Bash)
# --------------------------------------------

die() {
  echo "ERROR: $*" >&2
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

timestamp() {
  date -d"$1" +"%Y%m%d_%H%M%S"
}

# 1) Check prerequisite: adb exists
have_cmd adb || die "adb not found. Install Android Platform Tools or ensure adb is in PATH."

# 2) Check that at least one device is connected and authorized
DEVICE_COUNT="$(adb devices | awk 'NR>1 && $2=="device" {count++} END {print count+0}')"
if [[ "$DEVICE_COUNT" -lt 1 ]]; then
  echo "Tip: Run 'adb devices' and ensure your emulator is running or phone is authorized."
  die "No authorized device detected."
fi

# If multiple devices: pick first device (simple approach)
SERIAL="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"

# 3) Create output directory
DATE="$(date)"
OUTDIR="report_$(timestamp "$DATE")"
mkdir -p "$OUTDIR"

echo "Using device: $SERIAL"
echo "Output folder: $OUTDIR"
echo

# 4) Collect raw data
echo "[1/5] Collecting device properties..."
adb -s "$SERIAL" shell getprop > "$OUTDIR/getprop.txt"

echo "[2/5] Collecting battery info..."
adb -s "$SERIAL" shell dumpsys battery > "$OUTDIR/battery.txt"

echo "[3/5] Collecting storage info..."
adb -s "$SERIAL" shell df -h > "$OUTDIR/storage.txt"

echo "[4/5] Collecting process list..."
# Some devices accept `ps`, some need `ps -A`
adb -s "$SERIAL" shell ps > "$OUTDIR/ps.txt" 2>/dev/null || adb -s "$SERIAL" shell ps -A > "$OUTDIR/ps.txt"

echo "[5/5] Collecting logcat snapshot..."
# logcat may be restricted or empty; don't fail script if it errors
adb -s "$SERIAL" logcat -d > "$OUTDIR/logcat.txt" 2>/dev/null || true

# 5) Build a readable summary
SUMMARY="$OUTDIR/summary.txt"

MODEL="$(grep -m1 "ro.product.model" "$OUTDIR/getprop.txt" | cut -d'[' -f2 | cut -d']' -f1 || true)"
ANDROID_VER="$(grep -m1 "ro.build.version.release" "$OUTDIR/getprop.txt" | cut -d'[' -f2 | cut -d']' -f1 || true)"
SDK_VER="$(grep -m1 "ro.build.version.sdk" "$OUTDIR/getprop.txt" | cut -d'[' -f2 | cut -d']' -f1 || true)"

BAT_LEVEL="$(grep -m1 "level" "$OUTDIR/battery.txt" | awk -F': ' '{print $2}' || true)"
BAT_STATUS="$(grep -m1 "status" "$OUTDIR/battery.txt" | awk -F': ' '{print $2}' || true)"

LOG_LINES="$(wc -l < "$OUTDIR/logcat.txt" 2>/dev/null || echo 0)"
PROC_LINES="$(wc -l < "$OUTDIR/ps.txt" 2>/dev/null || echo 0)"

{
  echo "Android Health Check Summary"
  echo "============================"
  echo "Timestamp     : $DATE"
  echo "Device serial : $SERIAL"
  echo
  echo "[Device]"
  echo "Model         : ${MODEL:-unknown}"
  echo "Android ver   : ${ANDROID_VER:-unknown}"
  echo "SDK level     : ${SDK_VER:-unknown}"
  echo
  echo "[Battery]"
  echo "Level         : ${BAT_LEVEL:-unknown}"
  echo "Status        : ${BAT_STATUS:-unknown}"
  echo
  echo "[Storage] (top of df -h)"
  head -n 10 "$OUTDIR/storage.txt" 2>/dev/null || true
  echo
  echo "[Counts]"
  echo "Processes lines : $PROC_LINES"
  echo "Log lines       : $LOG_LINES"
  echo
  echo "[Files generated]"
  ls -1 "$OUTDIR" 2>/dev/null || true
} > "$SUMMARY"

echo
echo "✅ Done!"
echo "Open: $SUMMARY"
