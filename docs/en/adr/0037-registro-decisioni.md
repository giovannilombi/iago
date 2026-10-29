# ADR-0037 — Decision log and people

- Status: accepted
- Date: 2026-10-13
- Spec references: FR-150…157, FR-174, sec. 8.4.2

## Context
Phase 2 introduces decisions as first-class objects, independent of their source (call, document, note), with a status and a "supersedes" relationship. The spec provides for the people involved as entities (`decision_entity`), but the `entity` table arrives with phase 3 extraction.

## Decision
- Migration `v6-decisions`: tables `decision`, `decision_entity`, `decision_tag` as in spec 8.4.2, plus the spec's `entity` table (with a `normalized` column to avoid duplicates), created now and used only for the **people typed by the user** on decisions. Phase 3 will add extracted entities to it.
- **Title and description**: `text` is the title (required, shown in the timeline, lists, chains, exports); `notes` is the optional long description, opened on request ("Details"). Both are indexed. A long passage taken from a transcript or note goes into the description, and its first sentence becomes the title.
- Outside a project, each decision prominently shows its project (or "Unfiled").
- Generic `kind` (`decision` | `action` | `open_question`); the UI exposes only `decision` (FR-157).
- **"Supersedes"**: creating or editing a decision that supersedes another sets the latter to `superseded`; removing the link or deleting the more recent decision brings the previous one back to `active` if no other supersedes it. Cycles are rejected.
- **Deleted source (FR-156)**: the decision keeps its text, date, and people; the source's status (available, in the Trash, deleted) is computed and shown. In the search index, decisions have no `item_id`, so they stay searchable.
- Decisions follow their item's project when the item is moved (unless they had been moved by hand). Deleting a project also deletes its decisions.
- Creation: from a bookmark (the bookmark becomes `converted`), from a transcript sentence (right-click; if part of the sentence is copied first, that part is used), from a document (copied text), from a note ("Promote to decision"), manual. Automatic suggestion arrives with phase 3.
- Default date: the moment in the call (start + timestamp) or the note's date.

## Consequences
- Project notes (block 3) can be a source of decisions without schema changes.
- The project export (block 5) will use `decisionChain` for the "Decision log" section.

## Update 2026-10-13: comparison and chain name
- **Other decisions:** in the details of a decision with no evolution, the other active decisions of the same stream appear, or of the project if the decision has no stream. From there they are linked with "This one supersedes it" (the other is older) or "It is superseded by this one" (the other is more recent).
- **Chain name:** optional. It is saved in `decision.chain_name` on the first decision of the chain (migration `v10-decision-chain-name`), is read from any decision in the chain, and appears in the LLM export as "evoluzione: «nome»".
