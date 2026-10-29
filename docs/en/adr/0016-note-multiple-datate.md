# ADR-0016 — Multiple, dated notes

- Status: accepted
- Date: 2026-10-11
- Spec references: v1.4 sec. 3.18 (FR-170…176); addendum H.16

## Context
A single notes field per row does not represent information that arrives at different times after a call (an email, an update, a decision made later), nor information tied to the project but not to an item.

## Decision
`note` table: zero or more notes per item, or tied to the project only; markdown text, editable `noted_at` date, optional type (`note`, `email`, `late_decision`, `update`), input mode (`typed` | `voice`). It replaces `item.notes`, which is never created (no existing data to migrate: the database is born in phase 1 already with `note`).

## Consequences
- Notes appear in the timeline at their date, in the "Addendum" section of exports, and can be promoted to a decision.
- "Delete everything" on an item with notes asks whether to delete them or move them to the project.
