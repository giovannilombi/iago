#!/usr/bin/env bash
# Fails if IAGO's own code uses network APIs outside the allowed places (spec 4.2, CLAUDE.md "Rete e
# privacy"). Allowed: the model downloads (ModelManager for transcription, EngineDownloader for the local engine,
# ADR-0048). Dependencies are not scanned: FluidAudio's downloader is kept offline (ModelHub.offlineMode) and MLX
# loads only local folders (MLXProvider gives it a downloader that refuses).
# Apple's on-device model (FoundationModels) is allowed only for the proposed titles (ADR-0042, ADR-0048).
# Teams' local API (ADR-0051) connects only to 127.0.0.1: the check below makes sure of it.
set -euo pipefail
cd "$(dirname "$0")/.."
PATTERN='URLSession|URLRequest|NWConnection|NWListener|NWEndpoint|CFSocket|CFStream|getaddrinfo|socket\(|WKWebView|SCNetworkReachability|Network\.framework|import Network'
ALLOWED='^(Packages/IAGOTranscription/Sources/IAGOTranscription/ModelManager.swift|Packages/IAGOEngine/Sources/IAGOEngine/EngineDownloader.swift|App/Sources/Calls/TeamsLocalAPI.swift):'
hits=$(grep -rnE "$PATTERN" App/Sources Packages/*/Sources --include='*.swift' | grep -vE "$ALLOWED" || true)
if [[ -n "$hits" ]]; then
  echo "Network API used outside the allowed places:" >&2
  echo "$hits" >&2
  exit 1
fi
if grep -nE "https?://|wss?://" App/Sources/Calls/TeamsLocalAPI.swift | grep -v "127.0.0.1" >/dev/null; then
  echo "TeamsLocalAPI.swift must connect only to 127.0.0.1" >&2
  exit 1
fi
TITLES='Packages/IAGOIntelligence/Sources/IAGOIntelligence/TitleSuggester.swift'
apple=$(grep -rnE "FoundationModels|LanguageModelSession|SystemLanguageModel" App/Sources Packages/*/Sources --include='*.swift' | grep -v "^$TITLES:" || true)
if [[ -n "$apple" ]]; then
  echo "Apple's on-device model used outside the proposed titles (ADR-0048):" >&2
  echo "$apple" >&2
  exit 1
fi
echo "Network check: OK (only the model downloads and Teams on 127.0.0.1; Apple's model only for titles)"
