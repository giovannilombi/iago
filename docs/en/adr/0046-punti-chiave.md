# ADR-0046 — Key points: decisions, tasks, and milestones

- Status: accepted
- Date: 2026-10-15
- Spec references: sec. 3.16; ADR-0014 (generic `decision` model with `kind`), ADR-0037; user request 2026-10-15

## Context
Besides decisions, the user wants to mark two other kinds of things in the timeline:
- **tasks**, that is things to do or in progress, which can stay as they are or become a decision;
- **milestones**, that is important facts to remember ("small milestones").

The name "Moments" would be confused with "Mark moment", which creates bookmarks.

## Decision
- **A single family, "Key points"**, on the existing `decision` table, distinguished by the `kind` field (ADR-0014):

  | Type | `kind` | Statuses | Mark |
  |---|---|---|---|
  | Decision | `decision` | Active · Superseded · Cancelled | green seal |
  | Task | `action` | Open (`active`) · Done (`done`, new) · Superseded · Cancelled | orange dashed circle |
  | Milestone | `milestone` | Reached (`active`) · Superseded · Cancelled | blue flag |

  No migrations are needed: `kind` and `status` are text.
- **Chains:** apply to all types. A task "becomes a decision" when a new decision supersedes it, and the chain shows task → decision. Chain name, people, tags, streams, and source are common to the three types.
- **Interface:**
  - the "Decisions" view becomes **"Key points"**, with a filter by type; by default it shows the active ones (valid decisions, open tasks, milestones);
  - in the timeline, "Add" offers Note, Task, Milestone, and Decision;
  - from notes, "Promote to…" offers the three types;
  - a task has "Mark as done", "Reopen", and "Becomes a decision…".
- **Export and Claude:**
  - the export lists key points with their type (`[Attività · Aperta]`, `[Tappa]`), while decisions stay `[Attiva]`;
  - MCP: `add_decision` and `list_decisions` have `kind` and the `done` status;
  - in the graph, tasks are pentagons and milestones triangles.

## Consequences
- A single log with a single chain logic, without new tables.
- In the code, the name `Decision` remains for tasks and milestones too. In the interface, the common name is "Key points".
