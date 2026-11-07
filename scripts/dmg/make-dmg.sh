#!/usr/bin/env bash
# Builds IAGO's DMG (ADR-0097): IAGO, a link to Applicazioni and the instructions «Leggimi - Read me», on the
# background of scripts/dmg, laid out by dmgbuild without Finder, signed with the app's identity. Also copies it as
# dist/IAGO.dmg, the fixed name of the README's download link. Used by scripts/release.sh; on its own it rebuilds the
# DMG of an app already built.
#
#   scripts/dmg/make-dmg.sh <IAGO.app> <version>
set -euo pipefail
cd "$(dirname "$0")/../.."
APP=${1:?path of IAGO.app}
VERSION=${2:?version}
DMG="dist/IAGO-$VERSION.dmg"
DMGBUILD=build/venv-dmg/bin/dmgbuild
if [[ ! -x "$DMGBUILD" ]]; then
  python3 -m venv build/venv-dmg && build/venv-dmg/bin/pip install -q "dmgbuild==1.6.5"
fi
mkdir -p dist
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
README="$STAGE/Leggimi - Read me.html"
# The page with the app icon inside, so it works with no other file and no network.
python3 -c '
import base64, sys
icon = "data:image/png;base64," + base64.b64encode(open(sys.argv[2], "rb").read()).decode()
page = open(sys.argv[1], encoding="utf-8").read().replace("__ICON__", icon)
open(sys.argv[3], "w", encoding="utf-8").write(page)
' scripts/dmg/Leggimi.html App/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png "$README"
# An empty or unfinished page would open white: never ship it.
grep -q "__ICON__" "$README" && { echo "Instructions without the icon" >&2; exit 1; }
[[ $(wc -c <"$README") -gt 20000 ]] || { echo "Instructions empty or too short" >&2; exit 1; }
rm -f "$DMG" dist/IAGO.dmg
"$DMGBUILD" -s scripts/dmg/settings.py -D app="$APP" -D readme="$README" \
  -D icon=scripts/dmg/volume.icns -D background=scripts/dmg/background.tiff "IAGO $VERSION" "$DMG" >/dev/null
IDENTITY=$(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -1)
[[ -n "$IDENTITY" ]] && codesign --sign "$IDENTITY" "$DMG"
cp "$DMG" dist/IAGO.dmg
echo "Written $DMG and dist/IAGO.dmg"
