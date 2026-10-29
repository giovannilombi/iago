# ADR-0008 — UUIDv7, tombstones, versions and change log from the start

- Status: accepted
- Date: 2026-10-11
- Spec references: sec. 8.1, 13, 17.8

## Context
Sync and sharing will arrive in phase 4. Adding global identities, logical deletions and a change log after the fact would require painful migrations.

## Decision
Every user table has `id` UUIDv7, `created_at`, `updated_at`, `deleted_at` (tombstone), `version`, `device_id`. Every mutation also writes to `change_log`. Sensitive content is removed immediately; the row remains as a tombstone until sync allows otherwise.

## Consequences
- Slight overhead in writes and in repository code, paid from the start.
- Queries always filtered on `deleted_at IS NULL`.
- Phase 4 starts from an already compatible model.
