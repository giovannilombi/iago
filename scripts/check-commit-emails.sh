#!/usr/bin/env bash
# Blocks commits that carry a personal email address (ADR-0065): author and committer must be an anonymous GitHub
# address (<id>+<user>@users.noreply.github.com, or GitHub's own noreply@github.com for merges made on the site), and a
# message never contains any other address. Usage: check-commit-emails.sh <rev-list arguments>, e.g. `main..HEAD`.
# Run by the pre-push hook and by the Privacy workflow, so a commit made with --no-verify or elsewhere is still caught.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
[[ $# -gt 0 ]] || { echo "usage: $0 <rev-list arguments>" >&2; exit 2; }

ALLOWED='^([0-9]+\+)?[A-Za-z0-9-]+@users\.noreply\.github\.com$|^noreply@github\.com$'
FAIL=0
for sha in $(git rev-list "$@"); do
  short=$(git rev-parse --short "$sha")
  for who in an:ae cn:ce; do
    email=$(git log -1 --format="%${who#*:}" "$sha")
    if ! printf '%s' "$email" | grep -q -E "$ALLOWED"; then
      echo "    $short: ${who%%:*} = $(git log -1 --format="%${who%%:*}" "$sha") <$email>" >&2
      FAIL=1
    fi
  done
  OTHERS=$(git log -1 --format='%B' "$sha" | grep -o -E '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
    | grep -v -E "$ALLOWED" || true)
  if [[ -n "$OTHERS" ]]; then
    echo "    $short: message contains $(printf '%s' "$OTHERS" | sort -u | tr '\n' ' ')" >&2
    FAIL=1
  fi
done

if [[ $FAIL -ne 0 ]]; then
  echo "✘ Personal email addresses in the commits above (ADR-0065)." >&2
  echo "  Set: git config user.email <id>+<user>@users.noreply.github.com (GitHub › Settings › Emails)," >&2
  echo "  then rewrite them, e.g. git commit --amend --reset-author, or git rebase -i with --reset-author." >&2
  exit 1
fi
