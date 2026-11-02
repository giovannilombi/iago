# IAGO for Windows — Notes for when we start

> Project notes, gathered at the internal review board of 2026-11-02. Not a plan: it is what to read before starting.

## Why
- For people who get a non-Apple computer when hardware is replaced.

## What we already know
- **It is a rewrite, not a port.** Today's app uses SwiftUI and AppKit, the process tap for audio, MLX for the local engine and the Keychain: none of this exists on Windows.
- **It rewrites well, AI-assisted too:** interface, data model (SQLite), MCP server, export.
- **The sync is already designed for every client** (ADR-0082): a Windows client reads and writes the same shared spaces as the Macs, with the same project metadata (ADR-0083).

## Where the real time goes: field testing
On macOS these parts took weeks of testing. On Windows they have to be redone from scratch, and the estimate must be based on them, not on the code:
- **system audio:** capture with WASAPI loopback, a different API, with its own edge cases (headphones, device change during the call);
- **local transcription without MLX:** ONNX or DirectML, and quality must be measured again on the same test calls;
- **drift between the two tracks** under 50 ms over 2 hours, to be tested again;
- **meeting recognition** for Teams and Windows permissions;
- distribution and updates (code signing on Windows).

## Before starting
- Reread ADR-0082, ADR-0083 and the sync format specification.
- Start from the synthetic audio test fixtures (`scripts/make-fixtures.sh`) to keep the same acceptance criteria as the Macs.
