# Local engine

## Choice (ADR-0048)
- **MLX Swift inside the app** (`App/Sources/Engine`): no local server, no open port, no Ollama or similar. Apple Intelligence is not used for content.
- **4-bit quantized** models from `mlx-community` on Hugging Face, **pinned to a commit** and verified with the **SHA-256** of every file; the download starts only at the user's request.
- The catalog (`IAGOEngine/EngineCatalog.swift`) is generated with `scripts/make-engine-catalog.py`.

## Catalog
| Model | Parameters | Memory | Recommended | Use |
|---|---|---|---|---|
| Qwen 3.5 4B | 4B | about 3.5 GB | below 16 GB | Tidy up text, suggestions, Ask; **not** summaries |
| Qwen 3.5 9B | 9B | about 6 GB | 16 GB | everything, decent summaries (64-97 s per 30 minutes of call) |
| Gemma 4 12B | 12B | about 12.5 GB | 32 GB or more | everything, richer summaries (161-272 s) |
| Qwen3 Embedding 0.6B | 0.6B | 0.35 GB | always, with the first engine | semantic search |

- `EngineCatalog.recommended(forRAMGB:)` suggests Gemma from 32 GB up, the 9B from 16 GB, the 4B below. Gemma cannot be downloaded or used below 24 GB (`EnginePolicy.minimumRAMGB`).
- `EngineCatalog.minimumBillions` sets the minimum per function: summaries need at least 9B.
- **Under evaluation:** MiniCPM instead of the 4B or in addition to it (ADR-0067, proposed).

## Single queue and memory (ADR-0069)
- **`EngineLane`** (`IAGOEngine`): transcription, `MLXProvider` and `MLXEmbedder` all go through it, **one job at a time** on each Mac.
- **Priority:** a job is *interactive* when its task runs inside `EngineLane.$interactive.withValue(true)` (Ask, semantic search, Tidy up text). A background job in progress is cancelled and redone afterwards: every request to the engine is a block, so only that block is redone. Search-as-you-type is interactive but does not interrupt (`EngineLane.$preempts` set to `false`): it waits for the current block and jumps ahead of the next one, so a summary does not restart on every keystroke. `MLXProvider` checks for cancellation after `respond`, because MLX returns the partial text instead of an error.
- **Transcription:** not interruptible (`preemptible: false`); from 32 GB chat runs alongside it (`EnginePolicy.chatDuringTranscription`).
- **Memory** (`EngineMemory`): `Memory.cacheLimit` at 256 MB below 32 GB and 1 GB above; `DispatchSource.makeMemoryPressureSource` clears the MLX cache and calls `EngineLane.pauseBackground` (90 s, or 5 minutes and models released if critical). `Memory.memoryLimit` stays at the default.
- **`EnginePolicy`:** automatic jobs by default from 32 GB, model released at the end of a job below 32 GB, `minimumRAMGB` (Gemma 24 GB) and `replacement(for:installed:ramGB:)` to replace a model that does not fit.

## How a model is tested
- `open /Applications/IAGO.app --args -IAGOEngineBench "<titolo di un elemento>"` runs every downloaded model on that item (Tidy up text, suggestions, Ask) and writes timings and results locally.
- The test of summaries on real calls is described in [summaries and glossary](/en/benchmarks/2026-10-21-sintesi-e-glossario): only numbers and observations, never content.
- `scripts/test-engine.sh` builds the app with MLX and the Metal shaders; it must be run before every PR that touches the engine, and the CI runs it again on those PRs (`engine.yml`).
