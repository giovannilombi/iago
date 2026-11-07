## What changes
<!-- What the PR does and why, with the ADRs it follows or changes. -->

## Checks before the PR
<!--
Required for every PR (README-collaborators › Flusso di lavoro). The CI on GitHub runs the same checks again; these run
on your Mac: run `scripts/pre-pr.sh` on this branch and paste its summary here, in place of this comment (it is also in
build/pre-pr-summary.md). A PR without the summary, or with a red check, is not merged.
-->

## By hand
- [ ] Documentation in this PR: guide (Italian and English), `docs/tecnica`, ADR, `docs/prove-tester.md`, `docs/stato.md`, README if it describes what changed
- [ ] New interface texts translated (`scripts/i18n.py missing` / `apply`), new terms in `i18n/glossary.tsv`
- [ ] No real data: names, clients, audio, transcripts, emails; screenshots only from the demo archive
- [ ] Tried in the app (`scripts/install-app.sh`, or `scripts/try-branch.sh` with a new migration): what was tried
