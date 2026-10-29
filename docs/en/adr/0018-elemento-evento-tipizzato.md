# ADR-0018 — The item is a typed event in the project's history

- Status: accepted
- Date: 2026-10-11
- Spec references: v1.4 sec. 1, 3.19–3.21; addendum A, H.18

## Context
Besides calls, a project's history goes through emails and documents. Handling them in a separate model would duplicate project, tags, timeline, search, export, MCP.

## Decision
`item` has a `type` field (`call` | `email` | `document`, default `call`). All cross-cutting functions (title, `occurredAt`, project, category, tags, notes, decisions, `shared`, timeline, search, export, graph, MCP) apply to all types. Type-specific metadata in `email_meta` and `document_meta`; links between items in `item_link`. In the UI the term is "item".

## Consequences
- `item.type` is present from the first migration of phase 1 (no later migration).
- `asset.kind` is extended with the original and derived MD types.
- New `IAGOIngest` module for text extraction from emails and documents.
