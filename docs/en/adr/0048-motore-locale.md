# ADR-0048 — Local engine (LLM on the Mac)

- Status: accepted
- Date: 2026-10-16
- Spec references: sec. 4.2, 5.2 (`LLMProvider`), 10, open question C; FR-110, FR-121, FR-219; ADR-0042 (incorporated); user requests 2026-10-16

## Context
Phase 3 relies on a local language model for:
- automatic suggestions of decisions, tasks, and entities (FR-110);
- chat with citations (FR-121);
- "Tidy up text" (FR-219);
- suggested titles;
- later on, semantic search.

The user's requests:
- IAGO also works **without an engine**: everything that does not need one stays the same;
- it is the user who **downloads and chooses** the engine;
- without an engine, the features that need one stay visible and clickable, but warn and open the choice and the download;
- the "heavy" features (automatic suggestions, chat, semantic search) must not fall back on system models of uncertain quality, because it would undermine the app's credibility;
- the **suggested titles** for decisions born from notes and passages **always** stay with Apple Intelligence (ADR-0042): the model is already on the Mac, needs no download, and works well for short sentences;
- "Tidy up text" only with a local engine present and usable, never with Apple Intelligence.

## Decision

### 1. Engine inside IAGO, with MLX (closes open question C)
- The model runs **in IAGO's process** with Apple's **MLX** (`mlx-swift` and the official LLM library from `ml-explore`, MIT license). The exact version is pinned in `Package.resolved` at implementation.
- **No Ollama and no `localhost` port.** No external app is needed and there is no open service on the Mac. Item 2 of sec. 4.2 ("localhost to local LLM") remains unused.
- **New package `IAGOEngine`** (→ Core), in pure Swift and without MLX:
  - `LLMProvider` protocol: generation of text and of JSON constrained to a schema, cancellable;
  - model catalog;
  - download and verification;
  - choice of the active engine;
  - a fake provider for tests.
  It is tested with `swift test` and therefore runs in CI like the other packages. `IAGOIntelligence` sees only the protocol, received from the app, without depending on MLX.
- **Only the `MLXProvider` adapter** imports MLX. It is a thin app target, `IAGOEngineMLX`: it loads the model from the folder and generates. MLX compiles Metal shaders, which `swift test` cannot compile, so the adapter is verified with `xcodebuild`:
  - locally, with `scripts/test-engine.sh`, before every PR that touches it;
  - in CI, a separate **manual-only** job (`workflow_dispatch`), to run when needed.
  This keeps CI within GitHub Free's free minutes: macOS runners count 10 times, and an MLX build would cost about 10 minutes, that is about 100 of the 2,000 monthly minutes, on every PR.
- **Telemetry:** no network calls from the libraries. Models are loaded only from a local folder. The libraries' hub download is not used, and the `check-network-apis.sh` check verifies it.

### 2. Curated catalog, user's choice
- Only **reliable models with a clear license**, from the **Qwen** (Alibaba, Apache 2.0) and **Gemma** (Google, Gemma Terms of Use) families, in 4-bit quantized MLX versions. The initial catalog has 3 models, from about 4B to about 12B parameters; the exact names are pinned at implementation, verifying that they exist.
- For each model the catalog lists:
  - name;
  - download size;
  - recommended RAM;
  - languages;
  - license;
  - fixed URLs, at the exact repository commit, with the **SHA-256 of every file**.
- **A single active engine** at a time, chosen by the user in **Settings › Engine**. There one downloads, cancels, deletes, and chooses "Use this one".
- Before the download, if the Mac's RAM is below the recommended amount, IAGO flags it and still lets the user decide.
- **The default model is decided after a trial** of 2-3 models on the user's real calls: extraction of decisions and tasks, titles, text tidying, timing.
  - The trial runs locally with a development tool.
  - The results go into `bench-out/`, never into the repository.
  - The default is only the one highlighted in the list: no download starts on its own.

### 3. Download
- **Only on user action**:
  - in the background, with percentage and speed, in Settings and in the menu bar menu;
  - cancellable;
  - resumed if interrupted, file by file;
  - each file verified with SHA-256: if it does not match, the download is discarded.
- Every download goes into the **access log** (`audit_log`, actor `model_download`): URL and size.
- The files live in `Application Support/IAGO/Models/LLM/<modello>/`.
- **When the download finishes:** a notification and, at the first opening, an **"The engine is ready"** card that presents the features now available, each with a button to try it.

### 4. Without an engine
- **Suggested titles:** always Apple Intelligence, as today (ADR-0042), with or without a local engine. If Apple Intelligence is not available, the first sentence remains as a placeholder. Apple Intelligence is used **only for titles**.
- **Engine features** (automatic suggestions, chat, semantic search, "Tidy up text"):
  - have a **common mark** (the engine icon);
  - without an active engine, a click opens **"A local engine is needed"**: what the feature would do, the fact that everything stays on the Mac, and the buttons **"Choose and download an engine…"** (opens Settings › Engine) and **"Not now"**;
  - **do not fall back** on Apple Intelligence or other system models.
- What does not use the engine stays as it is: recording and transcription of calls and voice notes (own transcription models), keyword search, OCR, timeline, decisions, MCP.

### 5. Features that use the engine
- **Block 3:** "Tidy up text" of a dictated note or a passage (FR-219), with preview and replacement only if confirmed. Titles stay with Apple Intelligence (ADR-0042).
- **Future:** summaries by call type, guided by the category (kickoff, 1to1, …), with the same engine.
- **Blocks 4-6:** automatic suggestions (FR-110), chat with citations (FR-121), semantic search. They will use the same `LLMProvider` and the same warning.
- Generated text is always a **suggestion**: it is shown and editable before saving, and is marked as suggested by the engine, with the model's name.

### 6. Performance
- Engine work items are `Job`s at QoS `.utility`, one at a time. The app stays responsive and a recording in progress always takes priority: long jobs wait for the call to end.
- The model is loaded at first use and unloaded from memory after 10 minutes of inactivity.
- No text in the logs: only duration, model, and number of tokens.

## Consequences
- IAGO stays fully usable even without an engine. The engine is a chosen and visible addition, never a hidden fallback.
- ADR-0042 stays valid as it is: titles belong to Apple Intelligence; all the rest of the intelligence belongs to the local engine.
- All the engine logic is in CI. Only the thin MLX adapter is tested with `xcodebuild`: locally before the PR, in CI only manually.
- Downloads of several GB, only if the user chooses them; the space used appears in Settings › Space.

## Change of 2026-10-21
- **Summaries only from 9B up** (`EngineCatalog.minimumBillions`). With a smaller model, the Summary block explains that a bigger engine is needed, and automatic summaries do not start. The 4B remains valid for suggestions, Ask, and tidying.
- **Recommended model:** Gemma 4 12B from 32 GB, **Qwen 3.5 9B from 16 GB** (previously the 4B), Qwen 3.5 4B below 16 GB.
- **Reason:** in the trial on three real calls the 4B kept 1 to 8 points, the 9B 10-17, Gemma 10-31 (`docs/benchmarks/2026-10-21-sintesi-e-glossario.md`).

## Change of 2026-10-27 (ADR-0069)
- Point 6 ("one job at a time") is implemented with the **single queue** of ADR-0069, which also applies to transcription and embeddings.
- Gemma 4 12B is no longer just a warning: below 24 GB it **can be neither downloaded nor used**, because it exceeds the memory macOS grants to the GPU.
