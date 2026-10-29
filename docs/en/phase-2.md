# Phase 2 — Organization: status

Goal (spec 18): IAGO as the project's chronology. Already brought forward in phase 1: timeline, documents and OCR, notes with attachments, Teams transcripts, management of projects and tags, trash.

| Block | Content | Status |
|---|---|---|
| 1 | Network guarantee and search (FTS5, filters, sorting) | ✅ merged (PR #9) |
| 2 | Decision log | ✅ merged (PR #10) |
| 3 | Client › Project › Stream hierarchy | ✅ merged (PR #11) |
| 4 | Project notes and voice notes | ✅ merged (PR #12) |
| 5 | Email (also dragged from Outlook), client/project people, links | ✅ merged (PR #13) |
| 6 | Export for LLMs, Obsidian, encrypted backup and audio export, editable Markdown | ✅ merged (PR #14, refinements PR #15) |

## Block 1 — Network and search

| Component | Where | Notes |
|---|---|---|
| Network check | `scripts/check-network-apis.sh`, CI | fails if network APIs appear outside `ModelManager`; link to LuLu in Settings › Privacy |
| Index | `IAGOStore/Search.swift`, `v5-search` migration | FTS5 per segment, paragraph and note; accents and case ignored; updated at every write, rebuilt once at launch (ADR-0036) |
| Search | `App/Sources/UI/SearchAndFilters.swift` | field in the window bar; results per passage grouped by item, matched word in bold; clicking opens the item and starts the audio from that point; inside a project it searches only in the project |
| Filters and sorting | `FilterBar`, `AppModel.LibraryFilter` | category, tag (more than one), type, status, period; sorting by date, title, duration, project; they apply to list and timeline |

## Block 2 — Decision log

| Component | Where | Notes |
|---|---|---|
| Archive | `IAGOStore/Decisions.swift`, `v6-decisions` migration | decisions, people, tags; "supersedes" chain; deleted source flagged; indexed in search (ADR-0037); 5 tests |
| Decisions view | `App/Sources/UI/Decisions.swift` | as a timeline; "Decisions" entry in the sidebar (all) and third view next to List/Timeline (per project); filters status (default active), person, tag; click → audio from the point or source; the superseded one sits under the one superseding it if they have the same day |
| Editor | `DecisionEditor`, `TokenField` | people and tags with similarity suggestions and confirmation before creating a similar name; project required for hand-written decisions (those from a source follow the source); warning if the date is earlier than the superseded decision, with a suggestion to align it |
| Search | `SearchScopeBar` | selectors Everything / Transcripts / Notes / Documents / Decisions; header "in the «X» project" or "in the whole archive" with switching between them; when changing section the search stays, the icon next to the field brings back the results |
| Creation | item detail, post-recording panel | bookmark → "Becomes a decision…"; right-click on a sentence → "Mark as decision…"; document: copy the passage and right-click; note → "Promote to decision"; "Add decision" / "New decision" |
| Timeline | `ProjectTimeline` | decisions as a green seal on the line, at their date (hidden if a filter on the items is active) |

## Block 3 — Client › Project › Stream hierarchy

| Component | Where | Notes |
|---|---|---|
| Archive | `IAGOStore/Hierarchy.swift`, `v7-hierarchy` migration | clients, streams, multiple streams on items and decisions, client/stream scopes for library, decisions and search (ADR-0038); 4 tests |
| Sidebar | `App/Sources/UI/Hierarchy.swift` | tree: pinned, clients › projects › streams, "No client"; drag a project onto a client; context menus (new stream, move to client, rename, delete); "+ Add" → project or client |
| Views | `ViewModePicker`, `FilterBar` | client = items/timeline/decisions of all its projects; stream = filtered view; in the project "Stream" filter; colored dots on details and decisions |
| Detail and decisions | `MetadataEditor`, `DecisionEditor` | multiple-choice Stream field with "+ New stream"; warning if moving to another project removes the streams |
| Search | `SearchScopeBar` | "Change scope": stream → project → client → whole archive |
| Settings › Projects | `ClientsPane`, `ProjectStreamsEditor` | clients (rename, archive, delete), client of each project, streams of each project |

## Block 4 — Project notes and voice notes

| Component | Where | Notes |
|---|---|---|
| Project notes | `Archive.notes(projectID:)`, `v8-asset-owner` migration | notes with no item, attachments encrypted with the project key, destroyed with the project (ADR-0039); 2 tests |
| Timeline | `ProjectTimeline` | project and item notes at their date (yellow, microphone if dictated); click, edit, promote to decision, delete; "Project note" at the top of the project view |
| Voice notes | `App/Sources/UI/VoiceNotes.swift`, `TranscriptionPipeline.dictate` | "Dictate" button in the editor (append / replace, level, duration), immediate transcription, audio deleted on save, "Retry / Discard audio", recovery at launch |
| Menu bar | `StatusItemController`, `VoiceNotePanel` | "Voice note…" (disabled during a call): panel that listens right away, destination = last item or a project; a call that starts stops and transcribes the note |
| Verification | DEBUG hook `-IAGODebugDictate <file>` | 7 s synthetic sentence transcribed exactly in 12 s including model loading |

## Block 5 — Email, people and links

| Component | Where | Notes |
|---|---|---|
| Parser | `IAGOIngest/EmailParser.swift` | local MIME, HTML → Markdown without WebKit (no remote images), headers from screenshots (ADR-0040); 3 tests |
| Archive | `IAGOStore/Email.swift`, `v9-email` migration | email_meta, conversations in any import order, item_link, contacts with role, suggested project; 4 tests |
| Import | `ArchiveService`, `EmailImportSheet` | `.eml`/`.emlx` from Import… or dragged (also from Outlook/Mail as promised files): confirmation with attachments (images < 20 KB excluded), suggested project, direction |
| New email | `NewEmailSheet` (sidebar "New email…") | fields by hand or "From screenshot in the clipboard" (OCR + suggested headers) |
| Detail | `EmailHeaderSection`, `LinksSection` | headers, editable direction, conversation; "Links" on all items with "Link to…" |
| Lists and timeline | `ItemIcon` | icon by type, direction, sender, number of links |
| People | `PeopleSheet`, Settings › Email and people | your addresses; internal colleagues; clients/suppliers on client or project (right-click → People…) |
| Multiple import | `EmailBatchSheet`, `Archive.classifyEmail` | several emails dragged together: stack + "One at a time" (3 of 12, Skip) or "All together" (prefilled table: conversation, people, domains, name in the subject; doubtful ones in orange at the top; multiple assignment); duplicates rejected by the archive (Message-ID); 1 test |
| Known domains | `DomainRulesEditor`, `Archive.roles(for:)` | `@dominio` → internal/client/supplier for the whole app (subdomains included); client domains in its "People…"; labels next to the addresses; 1 test |

## Block 6 — Export, backup, Obsidian, editable Markdown

| Component | Where | Notes |
|---|---|---|
| Export for LLMs | `IAGOExport/ProjectExporter.swift`, `LLMExportSheet` | Export icon in the view (project, client, stream, filters): index, decision log, items and notes in chronological order, token estimate, copy or save; 1 test |
| Audio export | `AudioExportSheet` | unencrypted .m4a (+ transcript .md) of the view or of the whole archive (Settings › Backup) |
| Encrypted backup | `IAGOStore/Backup.swift`, `BackupService`, Settings › Backup and transfer | Apple Encrypted Archive with password; DB + files + key; restore at relaunch, previous archive kept; also from onboarding (new Mac); 1 round-trip test |
| Obsidian | `IAGOExport/ObsidianMirror.swift`, Settings › Obsidian | vault + chosen projects, automatic update, files with iago_id only; 1 test |
| Editable Markdown | `updateContentMarkdown`, "Correct the text…" | automatic text kept and restorable, search updated; 1 test |
| Replaced archives | `BackupService.replacedArchives`, Settings › Backup | list with space used, deletion with triple confirmation (warning, DELETE, final confirmation): folder + key in the Keychain |
| Import | `ImportView` (sidebar) | from file, from the clipboard (preview before importing: file, image with OCR, text), from text (`.md` document), .eml email, email without a file; dragging still works on the whole window |
| Lists in emails | `Bullets.join` in `EmailParser` | Outlook bullet points and `<li><p>` recomposed, mentions without `<mailto:…>`; emails already imported reconverted once from the original (texts corrected by hand excluded); 4 tests |
