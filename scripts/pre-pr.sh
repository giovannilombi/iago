#!/usr/bin/env bash
# The checks every pull request needs, for everyone (README-collaborators › Flusso di lavoro): these run on the Mac of whoever
# opens the PR, before the CI on GitHub runs them again (and the checks that need the Mac's files, such as real names). It prints a summary to paste in the PR description
# (also in build/pre-pr-summary.md); a PR is not merged without it, or with a red check in the CI.
#
#   scripts/pre-pr.sh          checks what changed against origin/main
#   scripts/pre-pr.sh --all    every check, whatever changed
set -uo pipefail
cd "$(dirname "$0")/.."
ALL=${1:-}
LOG=build/pre-pr
mkdir -p "$LOG"

git fetch -q origin main 2>/dev/null || true
branch=$(git rev-parse --abbrev-ref HEAD)
[[ $branch == main ]] && { echo "On main: run it on the branch of the PR." >&2; exit 1; }
changed=$(git diff --name-only origin/main...HEAD; git diff --name-only HEAD; git ls-files --others --exclude-standard)
touches() { [[ $ALL == --all ]] || grep -qE "$1" <<<"$changed"; }

results=()
failed=0
# run <name> <log> <command…>: the command's output goes to the log, the outcome to the summary.
run() {
  local name=$1 log=$2
  shift 2
  echo "==> $name"
  if "$@" >"$LOG/$log.log" 2>&1; then
    results+=("- [x] $name")
  else
    results+=("- [ ] $name — FAILED, see $LOG/$log.log")
    failed=1
    echo "    failed: $LOG/$log.log" >&2
  fi
}

[[ -n $(git status --porcelain) ]] && echo "Note: uncommitted changes are checked too, but are not in the PR." >&2

run "Real data and email addresses (check-private-data, check-commit-emails)" privacy \
  bash -c 'scripts/check-private-data.sh --all && scripts/check-commit-emails.sh origin/main..HEAD'
run "Italian and English aligned (i18n.py check)" i18n python3 scripts/i18n.py check

if touches '^(Packages/|scripts/test-packages)'; then
  run "Package tests (test-packages.sh)" tests scripts/test-packages.sh
  count=$(grep -oE "Test run with [0-9]+ tests?" "$LOG/tests.log" | awk '{s+=$4} END {print s+0}')
  results[${#results[@]}-1]+=" — $count tests"
else
  results+=("- [x] Package tests: no package changed")
fi

if touches '^(App/|Packages/|project.yml)'; then
  run "App build, Debug (xcodebuild)" build bash -c '
    scripts/bootstrap.sh >/dev/null || exit 1
    xcodebuild -project IAGO.xcodeproj -scheme IAGO -configuration Debug build 2>&1 | tee /dev/stderr |
      grep -q "BUILD SUCCEEDED"'
else
  results+=("- [x] App build: no app code changed")
fi

if touches '^(App/Sources/Engine/|Packages/IAGOEngine/)'; then
  run "Engine build with MLX (test-engine.sh)" engine scripts/test-engine.sh
else
  results+=("- [x] Engine build: engine not changed")
fi

if touches '^(docs/|App/Resources/Guide/|README)'; then
  run "Documentation site (npm run docs:build, broken links fail)" docs npm run docs:build
else
  results+=("- [x] Documentation site: no documentation changed")
fi

# ADR-0068: code changes come with their documentation (the commit-msg hook checks each commit; this the whole PR).
if grep -qE '^(App/Sources/|Packages/[^/]+/Sources/|project.yml)' <<<"$changed" \
  && ! grep -qE '^(App/Resources/Guide/|docs/)' <<<"$changed"; then
  results+=("- [ ] Code changed but no guide or docs/ file: update them, or explain why in the PR")
fi

summary="### Checks before the PR (scripts/pre-pr.sh)
Branch \`$branch\` at \`$(git rev-parse --short HEAD)\`, $(date '+%Y-%m-%d %H:%M'), macOS $(sw_vers -productVersion), Xcode $(xcodebuild -version 2>/dev/null | head -1 | awk '{print $2}').

$(printf '%s\n' "${results[@]}")"
echo "$summary" >build/pre-pr-summary.md
echo
echo "$summary"
echo
if [[ $failed == 0 ]]; then
  echo "All checks passed. Paste the summary above in the PR description (also in build/pre-pr-summary.md)."
else
  echo "Some checks failed: fix them before opening the PR." >&2
fi
exit $failed
