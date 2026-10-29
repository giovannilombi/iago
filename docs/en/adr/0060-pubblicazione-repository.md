# ADR-0060 — Publishing the repository

- Status: accepted (to be carried out when the user says they are ready to distribute)
- Date: 2026-10-21
- References: ADR-0034 (CC BY-NC-SA license), ADR-0056 (`giovannilombi/iago` feed); CLAUDE.md › Rules

## Context
- The repository will be public, because updates are downloaded from its releases.
- The commit **history** contains real data from the user's calls: names of people and clients, the company domain. They have already been removed from the current files.
- Making the existing repository public would also publish the history.

## Decision (option B)
- **When:** only when the user says they are ready.
- **How:**
  - the current repository is renamed `iago-archivio` and stays private, with all the history and PRs;
  - a new public `giovannilombi/iago` is created with a **single commit** of the state of `main`. The name stays that of the Sparkle feed;
  - before publishing, the files are searched again for real names, and 1.0.0 is published with `scripts/release.sh 1.0.0 --github`.
- **Rules that apply right away:**
  - never real data in code, tests, examples in model instructions, documents and screenshots. Made-up names are used (Acme, Rossi, Anna…);
  - screenshots are taken from the demo archive (ADR-0061).
- **Rejected:**
  - A, publishing as is: it would expose the names in the history;
  - C, rewriting the history: GitHub keeps the copies tied to PRs, so it is not safe.

## Consequences
- The full history can only be consulted in the private archive.
- Subsequent PRs live in the public repository.
