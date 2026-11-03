# ADR-0089 — Commit co-authors until sharing

- Status: accepted
- Date: 2026-11-03
- References: ADR-0065 (clean repository, authors and rights)

## Context
- ADR-0065 gave the rights to Giovanni Lombi up to 1.0.0-beta and to both authors «from later versions». So the `commit-msg` hook added Gianluca Sestito as `Co-Authored-By` to every commit.
- The user's rule is a different one: the rights belong to Giovanni Lombi until the work on sharing (phase 4) starts, to both from the first version with that work, the first one made together.

## Decision
- Until then commits have only Giovanni Lombi as author.
- In `Config/team.txt` Gianluca Sestito's line stays commented out. The hook skips lines starting with `#`, so it does not add it.
- In the commit of the first version with the work on sharing the comment is removed. From there every commit names both, as ADR-0065 says.

## Consequences
- The commits already on `main` after 1.0.0-beta, up to 1.2.13-beta, also name Gianluca Sestito. They stay that way: rewriting them would mean recreating the repository (closed PRs keep the old commits).
- Before calling a commit done, its `Co-Authored-By` lines are checked.
