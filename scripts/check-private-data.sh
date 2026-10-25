#!/usr/bin/env bash
# Blocks a commit that would carry real data (ADR-0060, ADR-0065): recordings, audio, archives, models, the local spec,
# and any term listed in Config/private-terms.local (names of real people, clients and domains; one per line, ignored
# by git, so the list itself never leaves the Mac). Run by the pre-commit hook; `--all` checks every tracked file.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
if [[ "${1:-}" == "--all" ]]; then
  FILES=$(git ls-files)
else
  FILES=$(git diff --cached --name-only --diff-filter=ACMR)
fi
FAIL=0

# The commit's own author and committer use the anonymous GitHub address (ADR-0065), never a personal one.
if [[ "${1:-}" != "--all" ]]; then
  for ident in GIT_AUTHOR_IDENT GIT_COMMITTER_IDENT; do
    EMAIL=$(git var "$ident" | sed -n 's/.*<\(.*\)>.*/\1/p')
    if ! printf '%s' "$EMAIL" | grep -q -E '^([0-9]+\+)?[A-Za-z0-9-]+@users\.noreply\.github\.com$'; then
      echo "✘ The commit would be signed <$EMAIL>: use the anonymous GitHub address (GitHub › Settings › Emails)," >&2
      echo "    git config user.email <id>+<user>@users.noreply.github.com" >&2
      FAIL=1
      break
    fi
  done
fi
[[ -z "$FILES" ]] && exit $FAIL

BLOCKED=$(echo "$FILES" | grep -i -E '\.(m4a|wav|caf|mp3|aac|aiff|flac|mp4|mov|enc|sqlite|sqlite3|db|vtt|eml|bin|gguf|safetensors)$|(^|/)(test-recordings|bench-out|Models|fixtures/generated)/|IAGO-spec|HANDOVER[^/]*\.md|private-terms\.local$' || true)
if [[ -n "$BLOCKED" ]]; then
  echo "✘ Files that must never be committed (recordings, archives, models, local notes):" >&2
  echo "$BLOCKED" | sed 's/^/    /' >&2
  FAIL=1
fi

# Personal email addresses never go in the repository (ADR-0065): authors are named by their anonymous GitHub address,
# examples use invented domains. Personal mailbox providers are blocked; real work domains go in private-terms.local.
EMAILS=$(while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  if [[ "${1:-}" == "--all" ]]; then CONTENT=$(cat "$file"); else CONTENT=$(git show ":$file" 2>/dev/null || true); fi
  printf '%s' "$CONTENT" | grep -o -i -E '[a-z0-9._%+-]+@(gmail|googlemail|icloud|me|mac|hotmail|outlook|live|msn|yahoo|libero|virgilio|tiscali|alice|tim|fastwebnet|email|proton|protonmail|pm|gmx|aol)\.[a-z.]{2,6}' | sed "s|^|$file: |" || true
done <<< "$FILES")
if [[ -n "$EMAILS" ]]; then
  echo "✘ Personal email addresses (authors use the GitHub noreply address, examples an invented domain):" >&2
  echo "$EMAILS" | sort -u | head -10 | sed 's/^/    /' >&2
  FAIL=1
fi

TERMS=Config/private-terms.local
if [[ -f "$TERMS" ]]; then
  PATTERNS=$(grep -v -E '^\s*(#|$)' "$TERMS" || true)
  if [[ -n "$PATTERNS" ]]; then
    while IFS= read -r file; do
      [[ -f "$file" ]] || continue
      if [[ "${1:-}" == "--all" ]]; then CONTENT=$(cat "$file"); else CONTENT=$(git show ":$file" 2>/dev/null || true); fi
      HITS=$(printf '%s' "$CONTENT" | grep -n -i -w -F -f <(printf '%s\n' "$PATTERNS") || true)
      if [[ -n "$HITS" ]]; then
        echo "✘ Real data in $file (terms from $TERMS):" >&2
        echo "$HITS" | head -5 | sed 's/^/    /' >&2
        FAIL=1
      fi
    done <<< "$FILES"
  fi
else
  echo "warning: $TERMS missing — real names are not checked (see Config/private-terms.local.example)" >&2
fi

[[ $FAIL -eq 0 ]] || { echo "Commit blocked: replace the real data with invented examples (Acme, Rossi, Anna…)." >&2; exit 1; }
