#!/bin/zsh
# Retakes the guide's screenshots with the demo tour (DemoMode.swift), in Italian and English: an invented archive
# in a temporary folder, never the user's. The tour brings its window to the front for each shot: do not use the Mac
# meanwhile. Shots taken with the window inactive (grey traffic lights) are retaken, up to three times.
#
#   scripts/guide-screenshots.sh                 every shot, both languages, dark appearance
#   scripts/guide-screenshots.sh it riepilogo    only some shots (comma separated), one language
#
# Debug build only (the demo tour does not exist in Release).
set -euo pipefail
cd "$(dirname "$0")/.."
LANGS=${1:-"it en"}
ONLY=${2:-}
APPEARANCE=${IAGO_APPEARANCE:-dark}
WORK=$(mktemp -d "${TMPDIR:-/tmp}/iago-shots.XXXX")
trap 'rm -rf "$WORK"' EXIT

xcodebuild -project IAGO.xcodeproj -scheme IAGO -configuration Debug build | grep -E "error:|BUILD" || true
PRODUCTS=$(xcodebuild -project IAGO.xcodeproj -scheme IAGO -configuration Debug -showBuildSettings 2>/dev/null \
  | awk '/ BUILT_PRODUCTS_DIR /{print $3}')
APP="$PRODUCTS/IAGO.app/Contents/MacOS/IAGO"
[[ -x "$APP" ]] || { echo "Debug build not found" >&2; exit 1; }

# One run of the tour: writes <name>.png in $2 for each shot (all, or the list in $3).
tour() {
  local lang=$1 out=$2 shots=${3:-} name number
  local root; root=$(mktemp -d "$WORK/root.XXXX")
  rm -rf "$out"; mkdir -p "$out"
  local args=(-IAGODemoRoot "$root" -IAGODemoTour "$out" -AppleLanguages "($lang)" -askButtonHidden NO
    -appearance "$APPEARANCE")
  [[ -n "$shots" ]] && args+=(-IAGODemoShots "$shots")
  "$APP" "${args[@]}" >/dev/null 2>&1 &
  local pid=$!
  for _ in {1..1600}; do
    for ready in "$out"/*.ready(N); do
      name=${ready:t:r}; number=$(cat "$ready"); rm "$ready"
      screencapture -o -x -l "$number" "$out/$name.png"
    done
    [[ -f "$out/done" ]] && break
    kill -0 $pid 2>/dev/null || break
    sleep 0.25
  done
  kill $pid 2>/dev/null || true
}

# Halves the Retina shots into the guide's folder; only the guide's images, plus the sidebar cut from the window.
install_shots() {
  local src=$1 dst=$2 name width
  for file in "$src"/*.png(N); do
    name=${file:t:r}
    [[ -f "$dst/$name.png" || $name == scheda || $name == scheda-barra || $name == scheda-momenti ]] || continue
    width=$(sips -g pixelWidth "$file" | awk '/pixelWidth/{print $2}')
    sips --resampleWidth $((width / 2)) "$file" --out "$dst/$name.png" >/dev/null
  done
  sips --cropToHeightWidth 900 220 --cropOffset 0 0 "$dst/finestra.png" --out "$dst/barra-laterale.png" >/dev/null
}

# Window screenshots (1440 wide, not sheets) whose close button is not red: the window was not active.
inactive() {
  python3 - "$1" <<'PY'
import glob, subprocess, sys, tempfile, os
tmp = tempfile.mkdtemp()
for f in sorted(glob.glob(sys.argv[1] + "/*.png")):
    name = os.path.basename(f)[:-4]
    if name in ("importa", "modalita", "barra-laterale"):
        continue
    out = subprocess.run(["sips", "-g", "pixelWidth", f], capture_output=True, text=True).stdout
    if int(out.split()[-1]) != 1440:
        continue
    px, bmp = os.path.join(tmp, "px.png"), os.path.join(tmp, "px.bmp")
    subprocess.run(["sips", "-c", "2", "2", "--cropOffset", "25", "25", f, "--out", px], capture_output=True)
    subprocess.run(["sips", "-s", "format", "bmp", px, "--out", bmp], capture_output=True)
    data = open(bmp, "rb").read()
    offset = int.from_bytes(data[10:14], "little")
    blue, green, red = data[offset], data[offset + 1], data[offset + 2]
    if not (red > 180 and green < 120):
        print(name)
PY
}

for lang in ${=LANGS}; do
  dst=App/Resources/Guide/img
  [[ $lang == en ]] && dst=App/Resources/Guide/en/img
  tour "$lang" "$WORK/$lang" "$ONLY"
  install_shots "$WORK/$lang" "$dst"
  for try in 1 2 3; do
    missing=$(inactive "$dst" | paste -sd, -)
    [[ -z "$missing" ]] && break
    echo "$lang: retaking $missing (try $try)"
    tour "$lang" "$WORK/fix" "$missing"
    install_shots "$WORK/fix" "$dst"
  done
  echo "$lang: done"
done
