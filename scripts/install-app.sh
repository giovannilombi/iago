#!/usr/bin/env bash
# Builds the signed Release app and installs it in /Applications, so IAGO starts from Launchpad,
# Spotlight, the Dock or the Desktop like any other app. Same bundle ID and signing team as the debug
# build: macOS keeps the permissions and the keychain access.
#
#   scripts/install-app.sh            build + install (quits a running IAGO first)
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/bootstrap.sh >/dev/null
xcodebuild -project IAGO.xcodeproj -scheme IAGO -configuration Release -derivedDataPath build/DerivedData build \
  | grep -E "error:|BUILD" || true
APP=build/DerivedData/Build/Products/Release/IAGO.app
[[ -d "$APP" ]] || { echo "Build failed" >&2; exit 1; }
osascript -e 'tell application "IAGO" to quit' >/dev/null 2>&1 || true
sleep 2
rm -rf /Applications/IAGO.app
ditto "$APP" /Applications/IAGO.app
codesign --verify --deep --strict /Applications/IAGO.app
# Build products share the bundle ID: Launch Services may open a stale one from Spotlight or at login.
# Remove them so /Applications/IAGO.app is the only copy macOS knows about.
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
for stale in build/DerivedData/Build/Products/*/IAGO.app "$HOME"/Library/Developer/Xcode/DerivedData/IAGO-*/Build/Products/*/IAGO.app; do
  [[ -d "$stale" ]] || continue
  "$LSREGISTER" -u "$stale" || true
  rm -rf "$stale"
done
"$LSREGISTER" -f /Applications/IAGO.app
echo "Installed /Applications/IAGO.app"
open /Applications/IAGO.app
