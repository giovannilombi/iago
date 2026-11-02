# Architecture Decision Records

Every relevant architectural decision has a numbered ADR. An accepted ADR is not modified: to change it, a new ADR is written that replaces it (`Status: superseded by ADR-XXXX`).

## Format

```markdown
# ADR-NNNN — Title

- Status: proposed | accepted | rejected | superseded by ADR-XXXX
- Date: YYYY-MM-DD
- Spec references: sec. …

## Context
## Decision
## Consequences
```

## Index

0001–0012: decisions from spec v1.0 (sec. 17). 0013–0021: decisions from addendum v1.4 (sec. H, same order). From 0022: open decisions resolved during development.

| # | Title | Status |
|---|---|---|
| 0001 | Native Swift/SwiftUI app, no fork | accepted |
| 0002 | Two separate tracks, mix only for listening | accepted |
| 0003 | System track via global Core Audio process tap | accepted |
| 0004 | Mic track = microphone in use by the call app | accepted |
| 0005 | Transcription exclusively local, interchangeable engines | accepted |
| 0006 | VAD and diarization with FluidAudio | accepted |
| 0007 | SQLite (GRDB), per-row encrypted files, crypto-shredding | accepted |
| 0008 | UUIDv7, tombstones, versions and change log from the start | accepted |
| 0009 | Automatic tags and entities only as suggestions | accepted |
| 0010 | Claude access per project, MCP stdio, access log | accepted |
| 0011 | Notion excluded | accepted |
| 0012 | Future E2E sync on Cloudflare, no external service before then | accepted |
| 0013 | Decisions as first-class objects | accepted |
| 0014 | Generic `decision` model (`kind`) | accepted |
| 0015 | Graph as a computed projection, centered native view | accepted |
| 0016 | Multiple, dated notes | accepted |
| 0017 | Contexts for LLMs and Claude labeled by type and date | accepted |
| 0018 | The item is a typed event in the project's history | accepted |
| 0019 | Text extraction and OCR exclusively local | accepted |
| 0020 | No automatic access to email mailboxes | accepted |
| 0021 | Voice notes are normal notes; the audio is not kept | accepted |
| 0022 | Minimum macOS 15 (open decision A) | accepted |
| 0023 | Default ASR engine: whisper.cpp large-v3-turbo (open decision B) | accepted |
| 0024 | "Mark moment" points to 5 seconds before the click | accepted |
| 0025 | Microphone choice: multiple inputs per app and a wait before falling back | accepted |
| 0026 | Left click opens the menu, right click starts and pauses | accepted |
| 0027 | AES-GCM block-encrypted files | accepted |
| 0028 | Master key in the Keychain and per-item keys | accepted |
| 0029 | Phase 0 recordings imported into the encrypted archive | accepted |
| 0030 | Trash with automatic deletion after 30 days (open decision D) | accepted |
| 0031 | "Several people in the room" option | accepted (IAGO decides by itself and those present: 1.2.8-beta) |
| 0032 | "Discard" during recording and "Temporarily discarded" | accepted |
| 0033 | Generic import, Teams transcripts and attachments in notes | accepted (Teams transcript side by side: 0078) |
| 0034 | IAGO license: Creative Commons BY-NC-SA 4.0 | accepted |
| 0035 | "Undefined" and project management | accepted |
| 0036 | FTS5 search index and control of network APIs | accepted |
| 0037 | Decision and people log | accepted |
| 0038 | Client › Project › Stream hierarchy | accepted |
| 0039 | Project notes, project attachments and voice notes | accepted |
| 0040 | Email: local MIME parser, conversations, links and people | accepted |
| 0041 | Encrypted backup, new Mac, export and Obsidian mirror | accepted |
| 0042 | Titles suggested by the Apple model on the Mac | accepted |
| 0043 | MCP server for Claude | accepted |
| 0044 | Writing through Claude (MCP) | accepted |
| 0045 | Graph view | accepted |
| 0046 | Key points: decisions, tasks and milestones | accepted |
| 0047 | Claude writes with context and preview | accepted |
| 0048 | Local engine (LLM on the Mac) | accepted |
| 0049 | Search by meaning, automatic suggestions and chat | accepted |
| 0050 | Watched folders for emails | accepted |
| 0051 | Recognizing Teams meetings, proposing recording and following mute | accepted |
| 0052 | Multiple supersessions and across different types | accepted |
| 0053 | macOS echo cancellation on the microphone | withdrawn |
| 0054 | Summary based on the category | accepted |
| 0055 | "Activity" section | accepted |
| 0056 | App updates | accepted (2 days of margin for mandatory ones: 1.2.8-beta) |
| 0057 | Sync through a shared cloud folder | proposed |
| 0058 | The data principle: nothing leaves without the user's choice | accepted |
| 0059 | Distribution without notarization | accepted (DMG since 2026-10-27) |
| 0060 | Publishing the repository | accepted (clean repository done with ADR-0065; publication still to do) |
| 0061 | Built-in guide, welcome tour and demo archive | accepted |
| 0062 | Transcription glossary | accepted |
| 0063 | Sidebar and cross-cutting access to categories and tags | accepted |
| 0064 | Echo cleanup after recording | rejected |
| 0065 | Clean repository, 1.0.0-beta and no real data in commits | accepted |
| 0066 | Initial example in a new archive | accepted (example projects with content: 1.2.10-beta) |
| 0067 | MiniCPM: instead of Qwen 3.5 4B or in addition | rejected |
| 0068 | Documentation site with VitePress on GitHub Pages | accepted (online when the repository is public) |
| 0069 | Single engine queue and memory | accepted |
| 0070 | Who produced each result | accepted |
| 0071 | Summaries and suggestions made by Claude | accepted |
| 0072 | Mark moment with screenshot and shortcuts in all apps | accepted |
| 0073 | Recognizing the same voices across different calls | accepted (room voices: 1.2.8-beta) |
| 0074 | Open work and two modes: Track and Manage | accepted (1.1.0-beta; modes redefined by 0076) |
| 0075 | Project views: how to look and what to show | accepted (1.1.0-beta; partly superseded by 0076) |
| 0076 | Simple Track mode, Inbox and Items | accepted (1.2.0-beta) |
| 0077 | Italian and English, always in sync | accepted (1.2.2-beta) |
| 0078 | IAGO's and Teams' transcripts side by side, Claude suggested on slow Macs | accepted (1.2.5-beta; search in both and ★ on the main one: 1.2.6-beta) |
| 0079 | Assistants beyond Claude: Claude, Claude Code, Gemini, Gemini CLI, ChatGPT, Codex CLI | proposed |
| 0080 | Sharing an item | accepted (1.2.7-beta) |
| 0081 | Getting-started introduction | accepted (1.2.9-beta) |
| 0082 | Sync usable by every client | accepted (principle, phase 4) |
| 0083 | Structured project metadata | accepted (principle, phase 4) |
| 0084 | Item detail: tiles, sticky bar and moments | accepted (1.2.11-beta) |
| 0085 | Overview of boxes, Track split in two, Activity across the window | accepted (1.2.12-beta) |
