# Intelligence

`IAGOIntelligence` turns text into answers. It uses the local engine through the `LanguageModel` protocol of `IAGOCore`: the package does not depend on MLX, and the tests use a fake engine.

## Search
- **Full text:** SQLite FTS5 ignoring accents and case, updated on save (ADR-0036).
- **Semantic:** the text is split into pieces (*chunks*) with the source item and minute, turned into vectors by **Qwen3 Embedding 0.6B** (MLX 4-bit, *last-token pooling*); similarity is the cosine over an in-memory matrix (ADR-0049).
- **Hybrid search:** the two lists are merged with *reciprocal rank fusion*. Without the embedding model, keyword search remains.
- **Scope** (`SearchScope`): the whole memory, a client, a project, a stream or **several chosen projects** (`.projects`, ADR-0091: sorted ids, at least two). `SearchScope.chosen(_:)` gives `.all` for no project, `.project` for one and `.projects` for two or more. The scope applies to search, the pieces of meaning search (`chunks`), new material (`changedSince`), open work suggestions and key points (`DecisionQuery.Scope.projects`).
- **Categories and tags** (ADR-0090): `Archive.summaries(categoryID:tagIDs:)` gives the items with the chosen category and **all** the chosen tags (one `item_tag` filter per tag); with neither category nor tags, those that have at least one of the two.
- **Two transcripts** (ADR-0078): search by words also looks in a call's other transcript, but only for calls where the main one has not already matched the words (`SearchHit.alternate`), so the same passage does not show twice. The vectors stay of the main one only; the MCP tools drop the other transcript's results, since Claude reads the main one.

## Key points (ADR-0046, ADR-0052, ADR-0074)
- **Six kinds** (`Decision.Kind`): memory (`decision`, `milestone`) and open work (`action`, `open_question`, `risk`, `request`, `Kind.isWork`). All with a source (item and minute, or note), people, date.
- **Statuses:** `active`, `in_progress`, `waiting`, `blocked`, `done`, `superseded`, `cancelled` (`Status.isOpen` for the first four). Closures with an outcome use `done` plus `outcome_kind` (`answered`, `accepted`, `rejected`, `converted`, `resolved`, `irrelevant`) and the text in `outcome`. `closed_at` follows the status (`Archive.stampClosed`).
- **Three relationships:** *supersedes / closes* (`decision_supersede`, ADR-0052; the UI reads it with the verb of the pair: replaces, answers, accepts, completes), *derived from* (`derived_from_id`), *depends on* (`decision_dependency`: an entry with an open blocker becomes `blocked` and returns to `active` when all are closed, `Archive.recomputeBlocked`; no cycles, `WorkError.dependencyCycle`).
- **Recurrences:** a `done` entry with `recurrence` creates the next one with the due date moved forward and the checklist to be done again (`Archive.repeatIfNeeded`).
- **Mode** (`WorkMode`, ADR-0076): per project in `project.work_mode`, null = `manage` (Manage mode); `Archive.workMode(projectID:)`. It changes only the UI: the global views (Inbox, Key points, everyone's Kanban) contain all projects and each entry is shown in its project's mode (`AppModel.workMode(for:)`). In `track`: a checkbox for tasks (`WorkCheckbox`), no Kanban and no "Show" (`AppModel.shownContent`), severity, "became an issue" and "derived from" hidden (`DecisionRow.hasManageDetails` flags them), Short overview (`WorkOverview.brief`). Preferences in `UserDefaults`: Graph turned off per project (`work.graphHidden`), first-visit window closed for good (`work.modeIntro.dismissed`, `WorkModeIntroSheet`); in the archive settings, so they travel with the backup, a client's mode for new projects (`work.clientMode.<id>`) and the projects with a manually chosen mode (`work.modeChosen`).
- Global register of key points, project timeline (ADR-0037), **Inbox** (`WorkInbox`, first entry in the sidebar; two badges: red for `OpenWork.needsAction`, that is my entries late or due today, with no owner and overdue waits; yellow for the suggestions to confirm, which the Inbox shows by item with `SuggestionRow`), **Overview** and **Kanban** (`App/Sources/UI/Work*.swift`).
- **Views** (ADR-0075, ADR-0076): `AppModel.ViewMode` (`overview` = Overview, `list` = Items, `timeline`, `board`, `map` = Graph) and `ViewContent` (`all`, `materials` = Items, `keyPoints`) for "Show", used only by the timeline and the graph; `TimelineRow.history` mixes items, key points and notes for the timeline. Kanban, Overview and Graph use the wide layout of `MainView` (sidebar and view, with the panel on the right); the choice is remembered per location in `UserDefaults` (`views.byScope`).
- **Import from a project** (`ImportSheet`, ADR-0076): `AppModel.ImportTarget` carries project and stream to `importFiles(_:into:)`, `importText(_:title:into:)` and `importClipboardImage(_:into:)`; imported items are assigned there, emails arrive with the project already chosen.
- **Status report** (`StatusReport`): the engine writes a project's status only from key points, in the engine's interactive lane; lines that do not cite an existing key point are removed.
- **Language of what the engine writes** (ADR-0077): `ContentLanguage` (IAGOCore) follows the app language, saved by the app in `UserDefaults` (`IAGOContentLanguage`). The instructions stay in Italian and say which language to write in; the summary templates have an English version (`SummaryLibrary.englishLibrary`, same ids and sections) and the fixed headings ("In brief", "Not mentioned", the status report headings) follow the language. Quotes stay as they were spoken.
- **Morning notification** (`WorkReminder`): a local notification on working days with counts of due dates, overdue items and expired waits; off until the user turns it on.

## Suggestions (ADR-0009, ADR-0049)
After every new piece of content the engine suggests decisions, tasks, open questions, risks, requests, speaker names, tags, project and links. Tasks carry who does them, by when and who is waited on; due dates spoken in words ("Friday", "end of the month", "in 3 days") are computed from the item's date (`DueDates`), not by the model. A suggestion can close an open entry of the project (answers an open question, accepts a request): `KeyPointExtractor` receives the latest open entries as candidates, in the same extraction pass. Every suggestion carries **the sentence it comes from**; IAGO looks for it in the text and discards those it cannot find. This holds for tags too (`SuggestionEngine.grounded`): a tag, existing or new, passes only if its sentence is in the text (`KeyPointExtractor.locateLine`) or its words appear in the text; otherwise a small model picked tags of other calls from the list just because they were there. Nothing is applied without confirmation.
- **Automatic or manual** (ADR-0069): automatic suggestions and summaries (`intelligence.autoSuggest`, `summaries.auto`) are on by default only from 32 GB (`EnginePolicy.automaticWorkByDefault`); the default is computed on each Mac and not saved. "Find suggestions" and "Generate summary" always work.
- **The background round** (`IntelligenceService.start`): one round (index, suggestions, summaries) when the archive changes (`poke()`) or at the latest after a minute. The one-minute timer, cancelled when the round starts earlier, must not wake it in turn: up to 1.2.2-beta it did, the round restarted without pause and kept the main thread busy (a stuttering window).
- **Provenance** (ADR-0070): `suggestion.origin` and `summary.origin` (`engine` or `claude`) and `model`; a confirmed key point keeps `decision.model`. The UI uses `Provenance` for the same line everywhere, with "small model" below 9B.

## Summaries by category (ADR-0054)
- The item's **category** chooses the **summary template**: 18 templates in Meetily's JSON format (sections with instruction, format and item format), taken from Meetily and Hyprnote (MIT) and editable.
- It needs an engine of **at least 9B** parameters (`EngineCatalog.minimumBillions["summary"] = 9`).
- **How the model is kept from making things up:**
  - the call is read in **10-minute blocks** (or 10,000 characters for texts without minutes). A line longer than 2,500 characters, such as compact JSON or text without line breaks, is first cut at the end of a sentence or at a space (`TextPieces`): no request to the engine can exceed the limit and fill up memory. The same limit applies to *Tidy up text*;
  - every point must include a **quote**; `KeyPointExtractor.locate` looks for it in the transcript with identical numbers and links the point to its minute, otherwise the point is discarded;
  - spoken sentences copied instead of summarized, personal facts and anecdotes are left out;
  - empty sections say "Not mentioned"; "In brief" is written only from verified points;
  - compact JSON with a limit of 2500 tokens; if the response is truncated or malformed, it is read section by section and then by patterns.
- The minutes in the summary are `iago://seek/N` links that restart the audio there.

## Ask IAGO (ADR-0049)
1. The question searches the chosen **context** (stream, project, client, several projects or the whole memory) with hybrid search, up to 40 pieces.
2. The pieces are grouped by item and numbered as **sources**; the model receives only those, with a labeled context (ADR-0017).
3. The answer must cite the sources `[n]`; a click on a source opens the item at the minute.
4. Conversations are kept for 48 hours, unless saved; when one is reopened, IAGO flags new material that arrived after the last answer.
5. "Change context" (ADR-0091) adds projects, narrows to some of them, moves to the whole memory or goes back to following the open section; the change opens a new conversation and repeats the last question (`ChatAnswerer.decisionScope` for key points). A conversation over several projects is saved with `scope_kind = "projects"` and the ids joined by commas in `scope_id`, without changing the schema.
6. **Chat state** (`ChatState`, `App/Sources/UI/ChatContext.swift`): question, conversation, answers and chosen context live in `AppModel.chat`, not in the view, so the conversation stays when moving from the pane to the whole window and when closing the pane. The chosen context also stays across launches in `UserDefaults` (`chat.context`: `all`, `project:id`, `projects:a,b`, `client:id`, `stream:id`); the demo tour neither reads nor writes it (`DemoMode.isActive`).

## Short titles (ADR-0042)
When a long text becomes a key point, Apple Foundation Models (macOS 26, if Apple Intelligence is on) suggests a title of at most 8 words. On the Mac, without network.

## Graph (ADR-0015, ADR-0045)
A read-only projection of a project's items, people, decisions and links, built from existing data.
