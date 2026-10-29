# ADR-0052 — Multiple supersessions and across different types

- Status: accepted
- Date: 2026-10-20
- Spec references: FR-151; ADR-0037 (decision log), ADR-0046 (key points), ADR-0047; user request 2026-10-20

## Context
A key point (decision, task, or milestone) can currently supersede **only one** (`decision.supersedes_id`). In practice, a milestone such as "Signed the PX7 and sent all the documentation" closes a decision and two earlier milestones at once. Claude also got stuck on this limit. The user wants any key point to be able to supersede **several entries of any type**.

## Decision
- **Links:**
  - new table `decision_supersede (newer_id, older_id, created_at)`, migration `v16-supersede-links`;
  - an entry can supersede many, and be superseded by several entries;
  - any type supersedes any type;
  - today's links are copied into the table. The `supersedes_id` column remains only for earlier versions of the app and is no longer read.
- **Status:**
  - an entry is **Superseded** if at least one entry that is neither cancelled nor deleted supersedes it;
  - when the last entry superseding it is cancelled, deleted, or unlinked, it goes back to **Active**. A "Done" task stays Done;
  - the status is recomputed on the affected entries at every change.
- **Checks:**
  - **no cycles**: an entry cannot supersede an entry that, directly or through others, already supersedes it;
  - **order change, as today (ADR-0047)**: if the chosen entry already comes later, with confirmation this entry moves after it, and whoever superseded it supersedes its predecessors;
  - **date earlier** than one of the superseded entries: a warning, not a block.
- **Interface:**
  - **editing:** "Supersedes" becomes a multiple choice (labels with ✕, plus "Add…" with the active entries, those of the project first);
  - **Evolution:** the list of all linked entries in date order. For the open entry, "Supersedes: …" and "Superseded by: …";
  - **chain name:** it lives on the oldest entry of the linked group;
  - **timeline and Key points:** an entry superseded on the same day appears under the most recent one that supersedes it;
  - **graph and exports:** show all the links.
- **Claude (MCP):** `add_decision` and `update_decision` accept `supersedes_ids` (a list). `supersedes_id` remains valid, as a list of one. The preview lists all the entries that will become superseded, and undo restores links and statuses as they were.
- **Engine suggestions:** they can continue to suggest a single entry to supersede. When they are confirmed, the link goes into the new table.

## Consequences
- The log reflects how things really go: a milestone or a decision closes several issues at once.
- The "chain" is no longer a line but a group of linked entries. Sorted by date, they stay as readable as before.
- An earlier version of IAGO that opens the archive sees only the first link of each entry, still via `supersedes_id`, which IAGO keeps updating with the most recent link.
