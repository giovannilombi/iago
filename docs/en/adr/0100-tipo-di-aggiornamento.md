# ADR-0100 — Kind of update chosen for every release, with the reason in the notes

- Status: accepted
- Date: 2026-11-10
- Changes: ADR-0056 (updates: major versions are no longer mandatory because of the number alone)
- References: user request of 2026-11-10

## Context
- An update was mandatory only when the first number went up (e.g. 2.0.0): `scripts/release.sh` decided it, and so did the app on its own (`UpdateService.isMajor`).
- An important fix inside a 1.3.x could not be made mandatory, and a major version could not be left optional.
- Sparkle hides «Skip This Version» only for *critical* updates, and IAGO treated every *critical* update as mandatory.
- The notes did not say why an update was mandatory.

## Decision
- **For every release the user chooses the kind**, and Claude Code always asks:
  1. **mandatory**, yes or no;
  2. if not mandatory, **can it be skipped**, yes or no.
- **The three kinds** (`scripts/release.sh --update`):
  - `optional`: install, later, skip. Like the earlier minor versions;
  - `no-skip`: no «Skip», but IAGO blocks nothing. In the appcast it is *critical* plus `<iago:update>no-skip</iago:update>`;
  - `mandatory`: *critical*. After 2 days IAGO starts no new recordings until it is updated (ADR-0056, change of 2026-10-30).
- **The notes always say what changes** (`--notes`, required). For `mandatory` they also say **why it is mandatory**; for `no-skip`, **why it matters to install it** even though we leave time (`--why`, required). The script adds the line in Italian and English and writes the notes as paragraphs in Sparkle's window.
- **The script stops** if `--update`, `--notes` or, for the two kinds that need it, `--why` is missing. For a major version it reminds that it is usually mandatory, but the choice stays with the user.
- **The app** (`UpdateService.isMandatory`) treats a *critical* update without `no-skip` as mandatory. The version number alone no longer makes it mandatory.

## Consequences
- An urgent fix can be made mandatory even in a 1.3.x. Installed versions already recognize it, since they have always read *critical*.
- **`no-skip` works from 1.3.3-beta**, the first version with this change. Earlier versions treat it as mandatory, with the block after 2 days: while someone uses an older version, prefer `optional` or `mandatory`.
- Versions up to 1.3.2-beta still treat every major version as mandatory, whatever kind is chosen.
- The rules are in `CLAUDE.md` and in `README-collaborators.md` › Making a release.
