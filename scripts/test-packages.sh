#!/usr/bin/env bash
# Runs `swift test` on every local package.
set -euo pipefail
cd "$(dirname "$0")/../Packages"
# No network call outside the allowed ones (README › Rete): the CI on GitHub runs only by hand, so it is checked here.
../scripts/check-network-apis.sh
for pkg in */; do
  pkg=${pkg%/}
  echo "==> $pkg"
  # A package that hangs fails after 10 minutes with its name, instead of blocking the whole run.
  perl -e 'alarm shift; exec @ARGV' 600 swift test --package-path "$pkg" "$@" \
    || { echo "✘ $pkg: tests failed or did not finish within 10 minutes" >&2; exit 1; }
done
