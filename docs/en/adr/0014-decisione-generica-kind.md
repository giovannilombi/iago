# ADR-0014 — Generic `decision` model (`kind`)

- Status: accepted
- Date: 2026-10-11
- Spec references: v1.4 FR-157; addendum H.14

## Context
Actions (action items) and open questions have the same shape as a decision: text, date, source, people, status, evolution.

## Decision
The `decision` table has a `kind` field (`decision` | `action` | `open_question`). In v1 the UI exposes only `decision`.

## Consequences
- Actions and open questions can be added in the future without schema migrations.
- Queries and views always filter by `kind`.
