#!/usr/bin/env bash
# Builds and publishes a release of IAGO (ADR-0056): version in project.yml, signed Release build, zip signed with
# Sparkle's EdDSA key (in the login keychain, account "iago"), appcast.xml with this version. A new major version is
# marked critical: users must install it before recording again. With --github the zip and the appcast go to a GitHub
# release (the app reads releases/latest/download/appcast.xml), with the DMG people install from (ADR-0059, amended):
# drag IAGO to Applicazioni, then "Apri comunque" once. Nothing else is pushed.
#
#   scripts/release.sh 1.0.0 [--notes "Novità…"] [--github]     (also 1.0.0-beta.2 for a beta)
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?version, e.g. 0.9.0}"; shift
NOTES=""; GITHUB=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --notes) NOTES="$2"; shift 2 ;;
    --github) GITHUB=1; shift ;;
    *) echo "Unknown option $1" >&2; exit 1 ;;
  esac
done
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-beta(\.[0-9]+)?)?$ ]] || { echo "Version must be x.y.z or x.y.z-beta[.n]" >&2; exit 1; }
PREVIOUS=$(sed -n 's/.*CFBundleShortVersionString: "\([^"]*\)".*/\1/p' project.yml)
BUILD=$(( $(sed -n 's/.*CFBundleVersion: "\([0-9]*\)".*/\1/p' project.yml) + 1 ))
CRITICAL=0
[[ "${VERSION%%.*}" -gt "${PREVIOUS%%.*}" ]] && CRITICAL=1
sed -i '' "s/CFBundleShortVersionString: \"[^\"]*\"/CFBundleShortVersionString: \"$VERSION\"/" project.yml
sed -i '' "s/CFBundleVersion: \"[^\"]*\"/CFBundleVersion: \"$BUILD\"/" project.yml

scripts/bootstrap.sh >/dev/null
# IAGO_DISTRIBUTION: only this build looks for updates (a build from source does not). The previous product is
# removed first, so a failed build can never be packaged under the new version.
rm -rf build/DerivedData/Build/Products/Release/IAGO.app
xcodebuild -project IAGO.xcodeproj -scheme IAGO -configuration Release -derivedDataPath build/DerivedData build \
  IAGO_DISTRIBUTION=YES | grep -E "error:|BUILD" || true
APP=build/DerivedData/Build/Products/Release/IAGO.app
[[ -d "$APP" ]] || { echo "Build failed" >&2; exit 1; }
codesign --verify --deep --strict "$APP"

mkdir -p dist
ZIP="dist/IAGO-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
# The DMG for the first installation (ADR-0097): IAGO, a link to Applicazioni and the instructions, on the background
# of scripts/dmg (arrows from IAGO to Applicazioni), laid out by dmgbuild without Finder; signed with the app's
# identity. IAGO.dmg is the same file under a fixed name, for the README's link to the latest version.
DMG="dist/IAGO-$VERSION.dmg"
DMGBUILD=build/venv-dmg/bin/dmgbuild
if [[ ! -x "$DMGBUILD" ]]; then
  python3 -m venv build/venv-dmg && build/venv-dmg/bin/pip install -q "dmgbuild==1.6.5"
fi
STAGE=$(mktemp -d)
ICON_DATA="data:image/png;base64,$(base64 -i App/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png)"
python3 - "$ICON_DATA" <scripts/dmg/Leggimi.html >"$STAGE/Leggimi - Read me.html" <<'PY'
import sys
sys.stdout.write(sys.stdin.read().replace("__ICON__", sys.argv[1]))
PY
rm -f "$DMG" dist/IAGO.dmg
"$DMGBUILD" -s scripts/dmg/settings.py -D app="$APP" -D readme="$STAGE/Leggimi - Read me.html" \
  -D icon=scripts/dmg/volume.icns -D background=scripts/dmg/background.tiff "IAGO $VERSION" "$DMG" >/dev/null
rm -rf "$STAGE"
IDENTITY=$(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -1)
[[ -n "$IDENTITY" ]] && codesign --sign "$IDENTITY" "$DMG"
cp "$DMG" dist/IAGO.dmg
SIGN_UPDATE=$(find build/DerivedData/SourcePackages/artifacts "$HOME"/Library/Developer/Xcode/DerivedData/IAGO-*/SourcePackages/artifacts \
  -name sign_update -path "*Sparkle*" 2>/dev/null | head -1)
[[ -x "$SIGN_UPDATE" ]] || { echo "Sparkle sign_update not found: build once with Xcode" >&2; exit 1; }
SIGNATURE=$("$SIGN_UPDATE" --account iago "$ZIP")   # sparkle:edSignature="…" length="…"
URL="https://github.com/giovannilombi/iago/releases/download/v$VERSION/IAGO-$VERSION.zip"
CRITICAL_TAG=""
[[ $CRITICAL -eq 1 ]] && CRITICAL_TAG="<sparkle:criticalUpdate sparkle:version=\"$VERSION\"></sparkle:criticalUpdate>"
python3 - "$VERSION" "$BUILD" "$NOTES" "$URL" "$SIGNATURE" "$CRITICAL_TAG" > dist/appcast.xml <<'PY'
import sys, html, email.utils
version, build, notes, url, signature, critical = sys.argv[1:7]
print(f'''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>IAGO</title>
    <item>
      <title>IAGO {version}</title>
      <pubDate>{email.utils.formatdate(localtime=True)}</pubDate>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      {critical}
      <description><![CDATA[{html.escape(notes) or "Nuova versione di IAGO."}]]></description>
      <enclosure url="{url}" {signature} type="application/octet-stream"/>
    </item>
  </channel>
</rss>''')
PY
echo "Release $VERSION (build $BUILD)$([[ $CRITICAL -eq 1 ]] && echo ", obbligatoria (nuova versione maggiore)")"
if [[ $GITHUB -eq 1 ]]; then
  gh release create "v$VERSION" "$DMG" dist/IAGO.dmg "$ZIP" dist/appcast.xml --title "IAGO $VERSION" --latest \
    --notes "${NOTES:-Nuova versione di IAGO.}"$'\n\n'"**Prima installazione:** scarica IAGO.dmg, aprilo, trascina IAGO in Applicazioni e segui «Leggimi» per la conferma da dare la prima volta (Impostazioni di Sistema › Privacy e sicurezza › Apri comunque, oppure un comando nel Terminale)."$'\n\n'"**First installation:** download IAGO.dmg, open it, drag IAGO to Applications and follow «Read me» for the confirmation needed the first time."
  echo "Published: https://github.com/giovannilombi/iago/releases/tag/v$VERSION"
fi
echo "Next: update README.md (Versioni) and commit it with project.yml (version $VERSION, build $BUILD)."
