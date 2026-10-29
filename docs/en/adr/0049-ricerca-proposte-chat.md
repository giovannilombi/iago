# ADR-0049 — Semantic search, automatic suggestions, and chat

- Status: accepted
- Date: 2026-10-19
- Spec references: sec. 10 (10.1-10.3 and v1.4 update), 8 (`suggestion`, `chunk`), 6.x (Share/Services); FR-101, FR-110, FR-111, FR-121, FR-150 (point 4), FR-201, FR-205; ADR-0048; user request 2026-10-19 (Blocks 4, 5, and 6 together)

## Context
With the local engine (ADR-0048), three Phase 3 features remain:
- **semantic search** (Block 4);
- **automatic suggestions** of decisions, tasks, people, tags, and links (Block 5);
- **chat with citations** and the **Share/Services** menu "Add to IAGO" (Block 6).

The same rules as for the engine apply:
- everything stays on the Mac;
- without an engine IAGO works as it does today;
- the features warn and offer the download;
- no fallback on Apple Intelligence;
- 16 GB Macs, the majority of users, must handle everything with Qwen 3.5 4B.

## Decision

### 1. Semantic search (Block 4)
- **Embedding model:** Qwen3 Embedding 0.6B in 4-bit MLX (`mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ`, Apache 2.0, about 350 MB). It is multilingual and supported by `MLXEmbedders`, the same library as the engine.
  - It is in the catalog with a pinned commit and the SHA-256 of every file, like the other models.
  - **It is downloaded together with the first engine**: the user makes a single choice, and the engine's row shows "+ 0.35 GB for search".
  - It can also be downloaded on its own, in Settings › Engine.
- **Chunks:** as in spec 10.1.
  - Calls are split by speaker turns, into chunks of 200-400 words with one turn of overlap, with start and end minute and speaker.
  - Emails, documents, and notes are split by paragraphs.
  - Table `chunk` (migration `v13-intelligence`) with the vector in a `BLOB` of normalized `float32`, plus the model that computed it. If the model changes, a job recomputes everything.
- **No `sqlite-vec`:** the comparison is a dot product in Swift with Accelerate over all vectors in the scope, that is project, client, or the whole archive.
  - With 10,000 chunks this is about 40 MB and a few milliseconds.
  - It adds no C dependency nor an SQLite extension to sign.
  - If more speed were needed, it could be changed behind the same interface.
- **Hybrid search** (spec 10.2):
  - keywords (FTS5, BM25) and meaning (cosine) are merged with Reciprocal Rank Fusion;
  - filters are applied before the fusion;
  - without an embedding model, today's keyword search remains, with a line explaining what would be added.
- **Background indexing:** jobs at QoS `.utility`, one at a time, after each transcription or import, plus an initial job over the whole archive with progress in the menu bar. During a recording, jobs wait.
- **MCP:** for now `search` stays keyword-based. The MCP server does not load models; the vectors are already in the database, but the model is needed for the query. To be evaluated later.

### 2. Automatic suggestions (Block 5)
- **When:** after a call's transcription and after importing an email or a document (FR-205), as a background job.
  - The "Suggest automatically" setting in Settings › Engine is on by default when there is an engine.
  - It can also be run by hand: "Find suggestions" in the item's detail view.
- **What it suggests:**
  - **decisions and tasks**, with `KeyPointExtractor`: strict definitions, 10-minute blocks, a verified quote that is strict on numbers, confidence, at most 12 per item;
  - **"supersedes"**: if a suggested decision resembles an active decision in the project, the suggestion says so ("May supersede «…»") and confirming links them;
  - **people**: speakers with a name, email senders and recipients, names mentioned and verified in the text, with merging into an existing person (FR-111);
  - **tags**: only among tags that already exist, so as not to invent new ones; plus at most 3 new tags, marked as such;
  - **project** for "Unfiled" items: chosen among existing projects, with the reason;
  - **links** (FR-201): the items closest in meaning in the same project, above a threshold, as `related`.
- **Where they are shown:**
  - in the item's detail view, the **"Suggestions (N)"** section with **Confirm**, **Edit…**, and **Discard**, and the quote with the clickable minute;
  - in the timeline, a mark on the item's card;
  - in Key points, the **"To confirm"** filter;
  - at the end of the job, a notification: "3 suggestions to review in «…»".
- **Never applied without confirmation.** A confirmed suggestion becomes a normal decision, task, person, tag, or link, with origin `extraction` and the model's name. A discarded suggestion does not come back at every new extraction of the same item.
- **`suggestion` table** (spec 8; migration `v13-intelligence`):
  - `id`, `item_id`, `kind` (`decision`, `activity`, `person`, `tag`, `project`, `link`);
  - `payload` JSON (text, quote, minute, confidence, target of any "supersedes");
  - `status` (`pending`, `accepted`, `rejected`, `merged`);
  - `model`, `created_at`.

### 3. Chat with citations (Block 6)
- **Where:** an **"Ask"** panel in the main window, on the selected scope (project, client, everything). It opens with ⌘K or with the button in the bar.
- **How it answers:**
  - it retrieves with hybrid search the most relevant chunks of the scope, about 12 with the small model, and gives them to the engine labeled by type and date, as in spec 10.3 v1.4: notes as "User's note of…", emails with direction, documents with the OCR warning;
  - the instructions say that the most recent information prevails, that conflicts must be flagged, and that for "what holds today" only active decisions count;
  - every statement has a clickable **[1] [2]** reference to the item and the minute;
  - an answer without sources says "I can't find anything in the archive about this".
  - With Qwen 3.5 4B the answers are short and in bullet points, and the panel reminds that they should be checked against the sources.
- **Conversations** (change of 2026-10-19, at the user's request):
  - they are saved in the `conversation` and `conversation_turn` tables (migration `v14-conversations`), with scope, questions, answers, cited sources, and the model's name;
  - they are **temporary for 48 hours** from the last question. At the top appears "Temporary conversation: deleted on… · **Keep**". They can be **pinned to the top**, and a pinned conversation is also kept;
  - the "Conversations" list is in the panel: pinned ones first, then the most recent. Automatic deletion happens at launch and then every minute, together with the background jobs;
  - when reopening a conversation, if the scope has **material added or changed after the last answer**, "New material added: the answer may be partial" appears, with **"Ask again"**. With the search model, the warning counts only the material relevant to the question; without it, it counts everything by date. It costs a single query, plus a search if the model is present;
  - a deleted source appears as "no longer available";
  - "Save as note" brings an answer into the project's notes.
- **Without an engine:** the panel opens and explains "A local engine is needed". Without an embedding model the chat uses keyword search, with less precision, and says so.

### 4. Share / Services (Block 6)
- **macOS "Add to IAGO" service**: text selected in any app, right-click › Services. The text arrives in IAGO's import as pasted text, with the choice of project. It is declared with `NSServices` in the Info.plist, without separate extensions or extra permissions.
- **The Share menu** for files (Finder, Mail) requires a separate, signed Share extension, with an App Group. It is postponed to distribution, and in the meantime dragging and "Import" remain.

### 5. Performance on 16 GB Macs
- Engine and embeddings never work together: jobs are queued and one runs at a time.
- During a recording no engine job starts; those in progress finish the current chunk and stop.
- The model leaves memory after 10 minutes of inactivity (ADR-0048). If macOS reports low memory, the job is suspended and resumes later.
- Chat takes priority over jobs: if the user asks a question, the job in progress waits.

## Consequences
- New migrations `v13-intelligence` (`chunk`, `suggestion`) and `v14-conversations`, with a backup before the update as for `v12`.
- One more model to download, small and tied to the first engine.
- `IAGOIntelligence` hosts chunking, hybrid search, extraction, and chat context, tested with a fake engine. The MLX part stays in the app (`App/Sources/Engine`).
- The full Share menu is postponed to distribution, because it requires a signed extension.

## Change of 2026-10-27 (ADR-0069)
- "Engine and embeddings one at a time", "chat takes priority", and "with low memory the job is suspended" are implemented by the **single queue** of ADR-0069: chat interrupts the block in progress, which is then redone.
- **"Suggest automatically"** is on by default only on Macs with 32 GB or more; below that, suggestions start from «Find suggestions», and the user can turn it back on.
