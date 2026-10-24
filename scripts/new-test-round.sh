#!/usr/bin/env bash
# Opens a GitHub issue "Prove <version> — <tester>" with every test of docs/prove-tester.md as a checkbox: the tester
# ticks what works and comments on what does not, and every collaborator reads it (README-collaborators.md › Prove).
#
#   scripts/new-test-round.sh "Nome Cognome" [version]     (version: default from project.yml)
set -euo pipefail
cd "$(dirname "$0")/.."
TESTER="${1:?tester name, e.g. \"Gianluca Sestito\"}"
VERSION="${2:-$(sed -n 's/.*CFBundleShortVersionString: "\([^"]*\)".*/\1/p' project.yml)}"
gh label create prove --color 0E8A16 --description "Prove manuali di una versione" >/dev/null 2>&1 || true
BODY=$(cat <<HEAD
Prove di **IAGO $VERSION** per **$TESTER**.

- Spunta la casella quando la prova funziona.
- Se qualcosa non va, scrivi un commento con il numero della prova (es. \`3h.4\`), cosa hai fatto e cosa hai visto. Se è un difetto, apriamo una issue a parte.
- Una prova non fatta resta senza spunta: scrivi nei commenti il perché.
- Nessun dato reale nei commenti: descrivi il comportamento, non il contenuto delle tue call o dei tuoi file.

Le prove vengono da [\`docs/prove-tester.md\`](../blob/main/docs/prove-tester.md) com'era all'apertura di questa issue.

---
HEAD
)
BODY+=$'\n'$(sed '1,/^> Questo documento/d' docs/prove-tester.md)
gh issue create --title "Prove $VERSION — $TESTER" --label prove --body "$BODY"
