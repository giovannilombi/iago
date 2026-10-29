# ADR-0058 — The data principle: nothing leaves without the user's choice

- Status: accepted
- Date: 2026-10-21
- Spec references: sec. 0 (principles), 4.2 (network); CLAUDE.md › Network and privacy; ADR-0005, ADR-0043, ADR-0044, ADR-0048, ADR-0056, ADR-0057; user's directions 2026-10-21

## Context
- The spec was born "privacy first, everything local", and the app's texts kept repeating "nothing leaves this Mac".
- In the meantime IAGO has become:
  - connectable to **Claude** (ADR-0043, 0044);
  - updatable from **GitHub** (ADR-0056);
  - designed for **sharing** in group spaces (ADR-0057).
- The user clarifies the concept: IAGO is the **queryable work memory**, and the data goes where the user decides.

## Decision
- **The principle:** nothing leaves the Mac unless the user wants it to.
- **Three levels**, each chosen explicitly:
  1. **on the Mac, by default:** encrypted archive, transcription and local engine (MLX) inside the app;
  2. **with Claude:** only the projects the user enables, writes with preview and confirmation, everything in the access log;
  3. **in a shared space** (phase 4): a cloud folder controlled by the user or the company (OneDrive, SharePoint, Google Drive, Dropbox). IAGO has no server.
- **Unchanged:**
  - no telemetry, statistics or remote crash reporter;
  - the only connections IAGO makes on its own are those listed in CLAUDE.md, checked in CI by `scripts/check-network-apis.sh`.
- **Communication:** README, guide, tour and settings put the queryable memory at the center. Recording is one of the sources, along with emails, documents, transcripts and notes. Privacy is presented as a choice, not as a limit.

## Consequences
- The "nothing leaves your Mac" texts without exceptions have been replaced in the guide, tour, settings and README.
- Every new way for data to leave (another service, another space) requires an ADR and an explicit choice by the user in the interface.
