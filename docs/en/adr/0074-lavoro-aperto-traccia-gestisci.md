# ADR-0074 — Open work and two modes: Track and Manage

- Status: accepted (1.1.0-beta; restore point `v1.0.1-beta`; updated by [ADR-0076](0076-modalita-inbox-elementi.md))
- Date: 2026-10-28
- References: ADR-0014 (`decision` model with `kind`), ADR-0046 (key points), ADR-0049 (suggestions), ADR-0052 (multiple supersessions), ADR-0071 (Claude); design [`docs/design/lavoro-aperto.md`](../design/lavoro-aperto.md); discussion with the user of 2026-10-27 and 2026-10-28

## Context
- IAGO is used by operational staff and by PMs. Key points (decision, task, milestone) record well what happened, but they do not say **what is open, whose it is, by when, what is blocking**.
- Open questions, risks, client requests, things waited for from others and checklists are needed, without getting lost in the timeline.
- We do not want to complicate use for those who do not manage projects, nor take features away from those who do.

## Decision
- **All kinds are always there.**
  - **Memory:** decision and milestone.
  - **Work:** task, with checklist; open question; risk, with severity and «became an issue»; request.
- **Two modes on the same data**, chosen **per project** (updated on 2026-10-28, during the trial: previously they were per person with per-project exceptions):
  - **Manage** (default): all statuses (including In progress and Blocked), priority, dependencies, estimate, start, recurrence, project and global kanban with free columns, complete overview with status report;
  - **Track**: statuses Open, Waiting, Done, Cancelled; basic fields (owner, due date, waiting for, checklist); short overview, no kanban.

  It is chosen from the «Manage ▾» pill next to the project name or in Settings › Projects. The global views (To do, Key points) are in Manage and each entry follows the mode of its project; the all-projects kanban leaves out projects in Track. Switching from one mode to the other loses no data. How views are shown: ADR-0075.
- **Three links:**
  - **supersedes / closes:** the one from ADR-0052, read with the fitting verb: replaces, answers, accepts, completes;
  - **derived from;**
  - **depends on.**
- **Closures with an outcome:** the answer to an open question; a request accepted, rejected with the reason or transformed; a risk resolved or no longer relevant.
- **Timeline:** closing adds no rows, it only changes the appearance.
  - Done: ✓, not struck through.
  - Superseded or cancelled: struck through, as today.
  - Closed by another entry on the same day: nested under it.
- **Suggestions** from the engine and from Claude for all kinds, always to be confirmed.
- **Data:** additive migration `v21-work` (details in the design). `kind` and `status` are text: today's entries are not converted.
- **Trials on a copy of the archive** (`scripts/try-branch.sh`) and development on the `feat/lavoro` branch until approval.
- **Out, for now:** calendar sync (on hold, it will require a network ADR), Plan the day, sending tasks to others before phase 4, sprints and estimate calculations.

## Consequences
- Those who only keep track put their projects in Track and see IAGO almost as it is today, plus the To do inbox and the short overview. Those who manage have the tools without a second program.
- The morning notification is off until the user turns it on (previously it followed the mode).
- ADR-0046 is extended (new kinds and statuses); ADR-0052 remains valid and its link becomes «supersedes / closes».
- MCP, exports, graph, guide, tour and tester checklist must be updated in each phase.
