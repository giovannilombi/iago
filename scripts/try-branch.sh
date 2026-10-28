#!/usr/bin/env bash
# Tries the checked-out branch on a COPY of the archive (~/IAGO-prova): the real archive is never opened, so going
# back is just quitting this build and opening IAGO again. A newer version migrates the database one way only, which
# is why it must not open the real archive until it is approved (README › Tornare a una versione precedente).
#   scripts/try-branch.sh           copy the archive the first time, then build and open the branch on the copy
#   scripts/try-branch.sh --fresh   copy the archive again, discarding the previous copy
# The script waits until the trial app quits, then removes the build so macOS never opens it in place of IAGO.
set -euo pipefail
cd "$(dirname "$0")/.."
ARCHIVE="$HOME/Library/Application Support/IAGO"
TRIAL="$HOME/IAGO-prova"
PRODUCT=build/TrialData/Build/Products/Debug/IAGO.app

if pgrep -x IAGO >/dev/null; then
  echo "Quit IAGO first (menu bar icon › Esci), then run this again." >&2
  exit 1
fi
[[ "${1:-}" == "--fresh" ]] && rm -rf "$TRIAL"
if [[ ! -d "$TRIAL" ]]; then
  [[ -d "$ARCHIVE" ]] || { echo "No archive at $ARCHIVE" >&2; exit 1; }
  echo "Copying the archive to ${TRIAL}..."
  ditto "$ARCHIVE" "$TRIAL"
fi

echo "Building $(git rev-parse --abbrev-ref HEAD) ($(git describe --tags --always))..."
scripts/bootstrap.sh >/dev/null
rm -rf "$PRODUCT"
xcodebuild -project IAGO.xcodeproj -scheme IAGO -configuration Debug -derivedDataPath build/TrialData build \
  | grep -E "error:|BUILD" || true
test -d "$PRODUCT" || { echo "Build failed" >&2; exit 1; }

echo "Opening the branch on the copy. Recordings made now go to the copy: use IAGO normally for real work."
open -W -n "$PRODUCT" --args -IAGOTrialRoot "$TRIAL"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -u "$PRODUCT" || true
rm -rf "$PRODUCT"
echo "Trial closed. The real archive was not touched; the copy stays in $TRIAL (--fresh to copy again)."
