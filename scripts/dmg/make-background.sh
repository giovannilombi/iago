#!/usr/bin/env bash
# Renders scripts/dmg/background.html into the DMG background (ADR-0097): background.tiff with the 1x (660×400) and
# Retina (1320×800) images, which Finder picks by screen. Run it after changing the HTML; the result is committed.
# Needs Google Chrome (headless, no window) and the network for the Google Fonts of the page.
set -euo pipefail
cd "$(dirname "$0")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[[ -x "$CHROME" ]] || { echo "Google Chrome not found" >&2; exit 1; }
TMP=$(mktemp -d)
for scale in 1 2; do
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --virtual-time-budget=8000 \
    --window-size=660,400 --force-device-scale-factor=$scale \
    --screenshot="$TMP/bg$scale.png" "file://$PWD/background.html" >/dev/null 2>&1
done
tiffutil -cathidpicheck "$TMP/bg1.png" "$TMP/bg2.png" -out background.tiff >/dev/null
cp "$TMP/bg2.png" background-preview.png
rm -rf "$TMP"
echo "Written scripts/dmg/background.tiff"
