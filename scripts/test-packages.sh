#!/usr/bin/env bash
# Runs `swift test` on every local package.
set -euo pipefail
cd "$(dirname "$0")/../Packages"
for pkg in */; do
  pkg=${pkg%/}
  echo "==> $pkg"
  swift test --package-path "$pkg" "$@"
done
