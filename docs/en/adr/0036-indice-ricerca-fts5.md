# ADR-0036 — FTS5 search index and network API check

- Status: accepted
- Date: 2026-10-12
- Spec references: FR-70, FR-71, FR-120, sec. 4.2, 9.3, 10.2

## Context
Text search (phase 2) must find passages in transcripts, notes, and documents and open the item at the right point. Files are encrypted per item: searching by decrypting every time would be slow. A verifiable guarantee is also needed that IAGO does not use the network outside the permitted cases.

## Decision
- **FTS5** virtual table `search_index` (tokenizer `unicode61`, accents removed): one row per transcript segment (with `at_sec`), per document paragraph, per note. Unindexed columns `item_id`, `project_id`, `source`, `source_id`.
- The **text is unencrypted in the database**, like titles and notes already are (spec 9.3): the database is excluded from Time Machine, and permanent deletion removes the rows (crypto-shredding + `secure_delete`).
- Synchronous update on every write (transcript, document, note, project change); full rebuild once at launch after an update (`search_index_version`).
- The user's query is turned into quoted words with prefix search: no injectable FTS syntax.
- **Network check**: `scripts/check-network-apis.sh` (also in CI) fails if network APIs appear in IAGO's code outside `ModelManager` (model downloads). In Settings › Privacy, a link to LuLu for independent verification.

## Consequences
- Semantic search (embeddings, phase 3) will sit alongside FTS with result fusion (spec 10.2).
- Dependencies are not analyzed by the script: FluidAudio stays offline (`ModelHub.offlineMode`).
