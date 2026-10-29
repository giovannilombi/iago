# Technical overview

This section is for those who work on IAGO or want to understand how it is built: architecture, data, pipelines, models, choices and their reasons. For how to **use** the app, switch to the **Usage** level with the selector at the top.

## IAGO in ten lines
- A **native macOS** app (Swift 6, SwiftUI with AppKit where needed), in the menu bar, **not sandboxed** and with the *hardened runtime*, so that it can record the audio of other apps.
- **Ten Swift packages** with a fixed dependency graph; the app target is the only one that imports SwiftUI and MLX.
- **Local archive:** SQLite (GRDB) with 17 migrations, block-encrypted files with one key per item in the Keychain.
- **Capture** on two tracks (system with a Core Audio *process tap*, microphone with a HAL IOProc) on the same system clock.
- **Local transcription:** whisper.cpp (default) or Parakeet on CoreML, VAD and diarization with FluidAudio.
- **Local understanding:** MLX engine inside the app (Qwen 3.5 4B/9B, Gemma 4 12B), Qwen3 0.6B embeddings, hybrid FTS5 + vector search.
- **No silent writes:** the engine suggests, the user confirms; every summary point must cite the transcript.
- **Claude optional** via MCP stdio, with writes only after preview and confirmation.
- **Network:** four allowed outbound connections, explicit and logged; a CI script blocks any others. No telemetry.
- **Distribution** without the App Store or notarization, updates signed with Sparkle from GitHub Releases.

## Where to find what
| Topic | Page | Main ADRs |
|---|---|---|
| Packages, data flow, job queue | [Architecture](./architettura) | 0001, 0055 |
| Database, encryption, migrations, backup | [Data and archive](./dati) | 0007, 0008, 0027, 0028, 0030, 0041 |
| Recording, microphone, meetings | [Capture and meetings](./cattura) | 0002, 0003, 0004, 0025, 0051 |
| Whisper, Parakeet, diarization, echo | [Transcription](./trascrizione) | 0005, 0006, 0023, 0062 |
| Emails, documents, OCR, watched folders | [Import](./importazione) | 0019, 0020, 0033, 0040, 0050 |
| Search, key points, suggestions, summaries, Ask | [Intelligence](./intelligenza) | 0036, 0046, 0049, 0052, 0054 |
| Local models, catalog, selection | [Local engine](./motore) | 0048, 0067 |
| MCP server, tools, writes | [Claude and MCP](./claude-mcp) | 0010, 0043, 0044, 0047 |
| Network, access log, data principle | [Privacy and network](./privacy-rete) | 0058 |
| Sparkle, releases, notarization | [Distribution and updates](./distribuzione) | 0056, 0059, 0060, 0065 |
| Setup, commands, CI, team rules | [Development](./sviluppo) | 0065, 0068 |
| All decisions | [Decisions (ADR)](/en/adr/) | — |
| Measurements and tests | [Quality and measurements](./qualita) | — |

The project status and open items are in [Status and roadmap](/en/stato).
