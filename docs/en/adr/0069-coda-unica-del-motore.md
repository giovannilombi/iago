# ADR-0069 — Single engine queue and memory

- Status: accepted
- Date: 2026-10-27
- References: ADR-0048 §6 (engine jobs one at a time), ADR-0049 (engine and embedding never together, chat has priority, suspension with low memory), ADR-0054 (summaries), ADR-0023 (transcription); user's directions of 2026-10-27

## Context
- On 16 GB Macs IAGO saturated memory during summaries, suggestions and key points.
- ADR-0048 and ADR-0049 promised one heavy job at a time, but the code did not do it:
  - AI work ran in a separate loop, which did not wait for transcription: LLM and Whisper/Parakeet could work together;
  - chat started even during a summary: two generations on the same model, with two caches;
  - the embedding model and the text model could stay loaded together;
  - no reaction to macOS low memory;
  - MLX keeps freed buffers aside up to all the memory it can use.
- A text with a huge line (a compact JSON) ended up whole in a single request: the likely cause of the hangs reported by a tester (see the fix of 2026-10-27, `TextPieces`).
- On Apple Silicon the GPU uses RAM: model, transcription and the user's apps must all fit together.

## Decision
- **A single lane** (`EngineLane`, in `IAGOEngine`) for all heavy work: transcription, text model, embedding. One job at a time, always, on every Mac: there is one GPU, and two jobs together do not finish sooner.
- **Chat has priority** (*interactive* work: Ask, meaning-based search, *Clean up text*):
  - a background job in progress is **interrupted immediately** and then **redone from the same step**: a chunk of a summary or of suggestions, a batch of indexing. At most one chunk is lost;
  - MLX stops generation at every token when the task is cancelled; the partial answer is never used (`MLXProvider` rechecks cancellation);
  - a **transcription cannot be interrupted**: chat waits for it to finish. On Macs with **32 GB** or more, chat can run alongside transcription.
- **Memory:**
  - limit on MLX's buffer cache: 256 MB below 32 GB, 1 GB above;
  - with the **memory pressure** signaled by macOS: MLX's cache is emptied and background work stops for 90 seconds (5 minutes and models released if pressure is critical); chat is not touched;
  - MLX's memory limit stays the default one: lowering it makes allocations wait and a request could hang.
- **Macs with less than 32 GB:**
  - **automatic suggestions and automatic summaries off by default**: they start from the buttons in the detail pane («Find suggestions», «Generate summary»), and the user can turn them on in Settings › Engine. The default is computed on each Mac and not saved, because the archive can move from one Mac to another; a choice made by the user stays;
  - the model is **released at the end of every background job**, instead of after 10 minutes of inactivity (after chat it stays loaded, because another question usually follows).
- **Gemma 4 12B requires at least 24 GB:** below that, it reaches 12.4 GB, beyond what macOS grants the GPU. It can be neither downloaded nor used; if it was active, IAGO switches to the largest installed model that fits (usually Qwen 3.5 9B) and says so with a notification. Previously IAGO warned but let you choose (ADR-0048).
- The rules live in `EnginePolicy` (`IAGOEngine`), with tests; the generated catalog does not change.

## Consequences
- It supersedes the points of ADR-0048 §6 and ADR-0049 on "one at a time", "chat has priority" and "low memory", which are now implemented here.
- With automatic suggestions and summaries off, on a 16 GB Mac results arrive only when you ask for them; those who want the previous behavior turn the two switches back on.
- A question in Ask during a long transcription, on a Mac below 32 GB, waits for the transcription to finish.
- An interrupted chunk is redone: with many questions in a row, a background summary takes longer.

## Clarification of 2026-10-27 (search)
- **Meaning-based search while typing** is interactive but **does not interrupt**: it waits for the current chunk to finish and goes ahead of the next chunk. Interrupting at every keystroke would keep restarting a background summary. Ask and *Clean up text* instead interrupt immediately.
