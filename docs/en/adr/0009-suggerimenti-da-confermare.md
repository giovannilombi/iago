# ADR-0009 — Automatic tags and entities only as suggestions

- Status: accepted
- Date: 2026-10-11
- Spec references: sec. 3.11 (FR-103), 3.12 (FR-111), 17.9

## Context
Extraction with a local LLM (phase 3) produces errors and duplicates. Applying it directly would pollute tags and entities, which are the basis of filters, links and exports.

## Decision
Everything proposed automatically (tags, entities, project, category) goes into the `suggestion` table and must be accepted, edited, merged or rejected by the user. Never applied automatically.

## Consequences
- An efficient review UI is needed (phase 3).
- Classified data stays reliable; entities support aliases for merges.
