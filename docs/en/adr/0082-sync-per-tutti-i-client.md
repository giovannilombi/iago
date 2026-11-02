# ADR-0082 — Sync usable by every client

- Status: accepted (principle for phase 4; no code yet)
- Date: 2026-11-02
- References: ADR-0012 and ADR-0057 (sync), ADR-0058 (nothing leaves the Mac unless the user wants it to), ADR-0073 (voice prints); internal review board of 2026-11-02

## Context
- Today IAGO exists only for macOS: SwiftUI and AppKit, process tap for audio, MLX for the local engine, the Keychain for keys. None of these parts carries over to another platform.
- Project sharing (phase 4) is the first piece of work after going public.
- Later a Windows version may be needed, for people who get a non-Apple computer. It will be a rewrite, not a port.
- If the sync format depends on Apple technologies, a future client won't be able to read or write the Macs' shared spaces.

## Decision
- **The shared space and the sync protocol are platform-neutral.** Any client (macOS today; Windows, command line or anything else tomorrow) must be able to read and write them without Apple code:
  - documented text files (JSON) with the **format version**, stable IDs, logical clocks (HLC) and content-addressed assets (SHA-256);
  - no Apple-specific formats (binary plists, `NSKeyedArchiver`, Core Data) and no dependency on the Keychain to read the space;
  - encryption and exchange of project keys only with standard primitives, available on every platform.
- **The format is written before the code**, in the technical documentation, and covered by test fixtures: a reader independent of the Swift code (a script, for example) must be able to read and write a test space.
- **Resolution rules live in the format, not in the client**, so every client decides the same way. User's direction: every shared project always has a **lead** and, when two people confirm the same suggestion differently, the lead's choice wins.
- Kept on the device only, for every client: voice prints (ADR-0073), preferences and personal keys. What gets shared stays the user's choice, tracked in the access log (ADR-0058).

## Consequences
- A client for another platform can be built without changing the Macs or the existing spaces.
- The sync can't use Apple-only shortcuts: it must be written and tested against the format.
- The sync design (ADR-0057, `docs/design/sync-cartella-condivisa.md`) must be checked against this principle before it is accepted.
