# ADR-0012 — Future E2E sync on Cloudflare, no external service before then

- Status: accepted
- Date: 2026-10-11
- Spec references: sec. 3.15, 13, 17.12

## Context
Sharing projects between users and access from web/mobile require a backend. The backend must not be able to read the contents.

## Decision
- Phase 4: Cloudflare Workers (API), D1 (encrypted metadata, change feed), R2 (encrypted blobs), end-to-end encryption (project key encrypted for each member with X25519).
- Phases 0–3: no external service. Only the sync fields in the model, the `change_log`, the `shared`/`sharing_enabled` flags and the empty interfaces in `IAGOSync` exist.

## Consequences
- The server sees only encrypted data, IDs and timestamps; search is always client-side.
- The Cloudflare account is created only in phase 4 (free plan, consistent with the "no paid services" constraint).
