#!/usr/bin/env bash
# Generates synthetic audio fixtures with macOS `say` (spec 16.4). Different Italian voices act as
# different speakers. Output: fixtures/generated/ (ignored by git — never commit audio).
#
#   import-dialogue.m4a          one track, three speakers (import pipeline + diarization)
#   recording/{mic,system}.m4a   two tracks: "Io" on mic, two remote speakers on system
#   recording-echo/              same, with the system audio leaking into the mic (-20 dB, +47 ms)
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")/.."
OUT=fixtures/generated
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

# speaker|track|text  (track: mic = Io, system = remote participants)
LINES=(
  "Eddy|system|Buongiorno a tutti, iniziamo con il punto sul progetto del portale clienti."
  "Reed|mic|Buongiorno. Io ho preparato la bozza della roadmap per il prossimo trimestre."
  "Flo|system|Perfetto. Prima però vorrei capire se la consegna di venerdì è confermata."
  "Reed|mic|Sì, la consegna è confermata, manca solo la revisione del design system."
  "Eddy|system|Bene. Allora decidiamo di spostare la demo al martedì successivo."
  "Flo|system|D'accordo. Io mi occupo di avvisare il cliente entro domani."
  "Reed|mic|Ottimo, aggiorno il documento e lo condivido nel canale del progetto."
)

manifest="$WORK/manifest.tsv"
: > "$manifest"
t=0.5
i=0
for line in "${LINES[@]}"; do
  IFS='|' read -r voice track text <<< "$line"
  file="$WORK/line$i.aiff"
  say -v "$voice" -o "$file" "$text"
  duration=$(afinfo "$file" | awk '/estimated duration/ {print $3}')
  printf "%s\t%s\t%s\t%s\n" "$track" "$t" "$duration" "$file" >> "$manifest"
  t=$(awk -v a="$t" -v b="$duration" 'BEGIN {print a + b + 0.6}')
  i=$((i + 1))
done

swift scripts/fixture-mixer.swift "$manifest" "$OUT"
echo "Fixtures written to $OUT"
