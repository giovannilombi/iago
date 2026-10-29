# Phase 3 — Intelligence and Claude: status

Goal (spec 18): Claude reads the enabled projects; search by meaning, extraction with suggestions, chat with citations and graph view, with an optional local engine that can be downloaded from the app.

| Block | Content | Status |
|---|---|---|
| 1 | MCP server for Claude, per-project flag, access log, connections per scope | ✅ merged (PR #16) |
| 2 | Graph view | ✅ merged (PR #17); graphic refinements at the end of the phase |
| 3 | Downloadable local engine (MLX, model of the user's choice: Qwen / Gemma), model test, "Tidy up text"; titles always Apple Intelligence (ADR-0048) | ✅ merged (PR #18) |
| 4 | Search by meaning (embedding + FTS5), ADR-0049 | 🚧 code and tests, user test queued |
| 5 | Automatic suggestions (decisions, tasks, supersedes, speaker names, tags, project, links), ADR-0049 | 🚧 code and tests, user test queued |
| 6 | Ask with citations and conversations saved 48 h, "Add to IAGO" service, ADR-0049 | 🚧 code and tests, user test queued |
| 8 | Watched folders for emails: delta, rules, discarded (ADR-0050) | 🚧 code and tests, user test queued |
| 9 | Meetings: Teams local API, call apps on the microphone, Calendar, provisional title, mute (ADR-0051) | 🚧 code and tests, user test queued |
| 10 | Multiple supersessions and across different types (ADR-0052) | 🚧 code and tests, user test queued |
| 11 | macOS echo cancellation on the microphone (ADR-0053), title of the right meeting with several meetings in progress (ADR-0051, amendment) | 🚧 code, tests and measurement test; user test queued |
| 12 | Summaries by category with Meetily/Hyprnote templates, two-level categories, "Categories and tags", sidebar by client (ADR-0054) | 🚧 code, tests and test on the real engine; evaluation on real calls queued |
| 13 | "Activity" section (ADR-0055) | 🚧 code and tests, user test queued |
| 7 | Writing from Claude via MCP: adding and editing notes and decisions, creating documents and inserting items (email, text). Transcripts, audio and originals stay non-editable. Every write goes into the log (ADR-0044, ADR-0047: preview and confirmation) | ✅ merged (PR #17) |

## Block 1 — MCP server (ADR-0043)

| Component | Where | Notes |
|---|---|---|
| Protocol | `IAGOMCP/MCPServer.swift` | JSON-RPC 2.0 over stdio, one line per message; `initialize`, `ping`, `tools/list`, `tools/call` |
| Tools | `IAGOMCP/IAGOTools.swift` | `list_projects`, `search`, `get_item`, `project_timeline`, `list_decisions`, `list_notes`, `get_thread`, `export_project`; only "Available to Claude" projects |
| Executable | `IAGO.app/Contents/MacOS/iago-mcp` (target `iago-mcp` in `project.yml`) | read-only archive + key from the Keychain; writes only one log line per call |
| Settings | `App/Sources/UI/ClaudePane.swift`, `ScopeSettings.swift` | enabled projects; choice of connection (all, all + unfiled, client, project) with "Add to Claude Desktop", command for Claude Code and list of the connections already present; Claude's reads; right-click on project or client › Settings… (General, Claude, People) |
| Sidebar | `Hierarchy.swift` | project with a dot in the text color, stream with a dash, client with a small colored square (click: color); Claude logo if readable, padlock if only in IAGO (click: settings) |

## Block 7 — Writing through Claude (ADR-0044)

| Component | Where | Notes |
|---|---|---|
| Permission | `project.claude_writable` (`v11-mcp-write` migration) | "Claude can also write", off by default, only for readable projects |
| Tools | `IAGOMCP/IAGOWriteTools.swift` | `add_note`, `update_note`, `add_decision`, `update_decision`, `create_document`, `add_email`; no tool touches transcripts, audio or originals |
| Provenance and undo | `IAGOStore/MCPChanges.swift`, `ViaClaudeBadge` | `input`/`origin`/`source` = `mcp`; `mcp_change` table; "Added/Edited via Claude (MCP)"; Settings › Claude › Undo |
| App refresh | `externalChangeCounter` (`PRAGMA data_version`) | IAGO reloads within 2 s when the server writes |
| Preview and context (ADR-0047) | `IAGOWriteTools.swift` (`WritePlan`, HMAC confirmation code), `IAGOTools.writingGuide` | every write: preview with date, position in the timeline and doubts (similar entries, dates, streams, order of the chain), then confirmation with code; default date now, `date="source"`; streams and links; `list_decisions` with `query`; MCP read/write annotations; `write_batch` (up to 20 notes and key points, one preview and one confirmation); warning on nearly identical notes; people and tags in the preview |
| Note streams | `note_stream` table (`v12-note-stream` migration), `NoteEditor`, stream timeline | also by hand from the app |
| Client permissions | `ClaudePane.permissionsGroup`, `ClaudeConnection.allowInClaudeCode` | steps for Claude Desktop; `mcp__<connessione>` in `~/.claude/settings.json` with confirmation |

## Block 2 — Graph view (ADR-0045)

| Component | Where | Notes |
|---|---|---|
| Model | `IAGOCore/Graph.swift` | nodes and edges, `asOf` (time cursor), `limited` (500 nodes: notes go first, then groups by month or year) |
| Projection | `IAGOIntelligence/GraphBuilder.swift` | projects, clients, items, people (entities, speakers, email correspondents), tags, decisions, notes |
| View | `App/Sources/UI/GraphView.swift` | fourth view "Graph"; Centered/All, types, date, zoom, dragging; click → right panel or detail; double-click expands |

## Block 3 — Local engine (ADR-0048)

| Component | Where | Notes |
|---|---|---|
| Protocol | `IAGOCore/LanguageModel.swift` (`LLMProvider`, `LLMRequest`) | features receive it from the app only if an engine has been chosen |
| Catalog, download, choice | `IAGOEngine` (`EngineCatalog`, `EngineDownloader`, `EngineLibrary`) | Qwen 3.5 4B and 9B, Gemma 4 12B, MLX 4-bit, pinned to a commit with the SHA-256 of each file (`scripts/make-engine-catalog.py`); resume with Range; `.verified`; `active.json` |
| MLX adapter | `App/Sources/Engine/MLXProvider.swift` | `mlx-swift-lm` 3.32.3 + `swift-transformers` 1.3.4 (Tokenizers); local folders only, a downloader that refuses; unloads memory after 10 min |
| Service and UI | `EngineService`, `EngineViews.swift` | Settings › Engine; "A local engine is needed"; "The engine is ready"; percentage in the menu bar; Space |
| Tidy up text | `IAGOIntelligence/TextTidier.swift`, `NoteEditor` | only with an engine; Before/After preview, "Replace" |
| Model test | `EngineBench` (`--args -IAGOEngineBench 3`) | report in `Application Support/IAGO/bench-out/` |
| Checks | `scripts/test-engine.sh`, `.github/workflows/engine.yml` (manual only), `check-network-apis.sh` | MLX is not part of the automatic CI; FoundationModels only in `TitleSuggester` |

## Blocks 4-6 — Search, suggestions, Ask (ADR-0049)

| Component | Where | Notes |
|---|---|---|
| Chunks and vectors | `IAGOStore/Intelligence.swift` (`chunk`, `v13-intelligence`), `IAGOIntelligence/SemanticSearch.swift` | speaking turns of 200-400 words; vectors in BLOBs, Accelerate; `HybridSearch` RRF |
| Search model | `EngineCatalog.embedding` (Qwen3 Embedding 0.6B), `App/Sources/Engine/MLXEmbedder.swift` | downloaded with the first engine |
| Background jobs | `IntelligenceService` | indexes, automatic suggestions for new items, "Find suggestions"; paused during recordings and chat |
| Suggestions | `suggestion`, `SuggestionEngine`, `Suggestions.swift` | Confirm / Edit / Discard; badges in list and timeline; "To confirm" in Key points |
| Ask | `ChatAnswerer`, `ChatPanel` (⌘K), `conversation` (`v14-conversations`) | numbered sources; conversations 48 h, Keep, Pin; "New material added" |
| Services | `ServiceProvider`, `NSServices` | "Add to IAGO" on the selected text |

## Watched folders (ADR-0050)

| Component | Where | Notes |
|---|---|---|
| Rules | `IAGOIngest/ImportRules.swift` | meeting invitations/replies, automatic replies, newsletters (off), the user's exclusions and assignments |
| Log | `IAGOStore/WatchedFolders.swift` (`v15-watched-folders`) | delta by path, size, date, SHA-256; duplicates by Message-ID |
| Service and UI | `FolderImporter`, `WatchedFoldersViews.swift` | Settings › Email and people; "Imported"; "Import anyway" |

## Meetings (ADR-0051)

| Component | Where | Notes |
|---|---|---|
| Teams local API | `App/Sources/Calls/TeamsLocalAPI.swift`, `IAGOCore/TeamsMeeting.swift` | ws://127.0.0.1:8124, pairing with `query-state`, token in the Keychain |
| Call apps on the microphone | `IAGOCapture/CallActivity.swift` | Teams, Zoom, Webex, FaceTime, Slack (not browsers) |
| Calendar | `MeetingCalendar` (EventKit) | provisional title, alert at the start time |
| Coordination | `CallDetector` | Ask / Record automatically / Do nothing; "The call has ended: stop?"; mute → silence on the mic track (`micMuted`) |
