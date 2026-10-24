#!/usr/bin/env bash
# Generates IAGO.xcodeproj from project.yml. Never edit the .xcodeproj by hand.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || { echo "xcodegen missing: brew install xcodegen" >&2; exit 1; }
if [[ ! -f Config/Local.xcconfig ]]; then
  echo "warning: Config/Local.xcconfig missing — copy Config/Local.xcconfig.example and set DEVELOPMENT_TEAM" >&2
fi
# Commit checks: no real data, no AI co-author (ADR-0065).
git config core.hooksPath scripts/git-hooks
[[ -f Config/private-terms.local ]] || echo "warning: Config/private-terms.local missing — see Config/private-terms.local.example" >&2
xcodegen generate
