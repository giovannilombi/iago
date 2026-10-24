#!/usr/bin/env bash
# Builds the app with the MLX adapter (App/Sources/Engine), which `swift test` cannot compile (Metal shaders,
# ADR-0048). Run before every PR touching the engine; CI runs it only on demand (workflow_dispatch "engine").
# The first run may need: xcodebuild -downloadComponent MetalToolchain
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/bootstrap.sh >/dev/null
swift test --package-path Packages/IAGOEngine
swift test --package-path Packages/IAGOIntelligence
xcodebuild -project IAGO.xcodeproj -scheme IAGO -configuration Release -derivedDataPath build/DerivedData build \
  CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-YES}" | grep -E "error:|BUILD" || true
test -d build/DerivedData/Build/Products/Release/IAGO.app || { echo "Build failed" >&2; exit 1; }
# Build products share the bundle ID: never leave one for Launch Services to open (see install-app.sh).
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -u build/DerivedData/Build/Products/Release/IAGO.app || true
rm -rf build/DerivedData/Build/Products/Release/IAGO.app
echo "Engine build: OK"
