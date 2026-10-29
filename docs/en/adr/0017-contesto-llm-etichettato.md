# ADR-0017 — Contexts for LLMs and Claude labeled by type and date

- Status: accepted
- Date: 2026-10-11
- Spec references: v1.4 sec. 10.3, 12; addendum H.17

## Context
Local chat and MCP give the LLM heterogeneous contents (transcripts, emails, OCR documents, notes) produced at different times and sometimes in conflict with each other.

## Decision
Every content passed to an LLM is labeled with type and date (e.g., "User's note of …", emails with direction and date, documents with a warning about possible OCR errors). The system instruction states that the most recent information prevails and that conflicts must be reported; for "what holds today", decisions with status `active` are used.

## Consequences
- More reliable answers on projects that evolve.
- The descriptions of the MCP tools explain item types, notes, decision statuses and OCR errors.
