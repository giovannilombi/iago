# ADR-0013 — Decisions as first-class objects

- Status: accepted
- Date: 2026-10-11
- Spec references: v1.4 sec. 3.16 (FR-150…157); addendum H.13

## Context
Decisions made in calls, emails or notes are the information most often requested after the fact ("what did we decide about X?"), but they evolve over time and their source can be deleted (audio removed, item deleted).

## Decision
The decision (`decision`) is a standalone object with text, date (`decided_at`), project, people, optional source (item + timestamp, or note), status (`active` | `superseded` | `cancelled`) and a "supersedes" relation (`supersedes_id`). If the source is deleted, the decision remains and only loses the link.

## Consequences
- "Decisions" view, markers in the timeline and a dedicated section in the project export.
- A decision that supersedes another automatically moves the previous one to `superseded`.
- Deleting an item must handle the references (`source_item_id` set to null) without losing decisions.
