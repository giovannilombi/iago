#!/usr/bin/env bash
# Downloads ASR models from fixed URLs and verifies SHA-256 (spec 4.2.1, 7.5). Run only on purpose:
# this is the explicit user action that allows the network access.
#
#   scripts/download-models.sh [whisper-turbo|whisper-large-v3]...   (default: whisper-turbo)
#
# FluidAudio models (Parakeet, VAD, diarization) are fetched by `iago-bench --allow-download`
# into ~/Library/Application Support/FluidAudio/Models.
set -euo pipefail
cd "$(dirname "$0")/.."
DEST=Models
mkdir -p "$DEST"
BASE=https://huggingface.co/ggerganov/whisper.cpp/resolve/main

download() {
  local file=$1 sha=$2
  local path="$DEST/$file"
  if [[ -f "$path" ]] && echo "$sha  $path" | shasum -a 256 -c --status; then
    echo "$file: already present, checksum OK"
    return
  fi
  echo "Downloading ${file}…"
  curl -L --fail --progress-bar -o "$path.part" "$BASE/$file"
  echo "$sha  $path.part" | shasum -a 256 -c --quiet
  mv "$path.part" "$path"
  echo "$file: checksum OK"
}

for model in "${@:-whisper-turbo}"; do
  case $model in
    whisper-turbo) download ggml-large-v3-turbo.bin 1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69 ;;
    whisper-large-v3) download ggml-large-v3.bin 64d182b440b98d5203c4f9bd541544d84c605196c4f7b845dfa11fb23594d1e2 ;;
    *) echo "Unknown model: $model" >&2; exit 2 ;;
  esac
done
