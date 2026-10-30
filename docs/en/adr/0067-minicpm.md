# ADR-0067 — MiniCPM: instead of Qwen 3.5 4B or in addition to it

- Status: rejected (user's decision of 2026-10-30: MiniCPM is not added to the catalog)
- Date: 2026-10-24
- References: ADR-0048 (MLX local engine, model catalog), ADR-0054 (summaries, 9B minimum)

## Context
- The local engine catalog today offers Qwen 3.5 4B, Qwen 3.5 9B and Gemma 4 12B, plus Qwen3 Embedding 0.6B for search.
- Qwen 3.5 4B is the lightweight model (8-16 GB Macs): it is fine for "Clean up text", suggestions and Ask, but it was excluded from summaries because it is too weak (ADR-0054).
- The user found **MiniCPM**, a family of small models that could do better in the same memory range.

## The two paths
1. **Replace** Qwen 3.5 4B with MiniCPM: simpler catalog, a single lightweight model.
2. **Add** MiniCPM alongside the current models: more choice, but one more model to maintain and explain.

## What must be verified before choosing
- **Version and format:** which MiniCPM (size, text-only variant), whether a reliable MLX conversion exists and whether it runs with our MLX adapter without changes.
- **License:** compatible with IAGO's free distribution (CC BY-NC-SA) and with in-app download; it must be read and recorded in `docs/licenses.md`.
- **Quality in Italian**, with the tests already used for the catalog (`-IAGOEngineBench`):
  - Clean up text: no number or name lost;
  - suggestions: valid JSON and sensible titles;
  - Ask: answers with the right sources;
  - summaries: if it comes close to the 9B, the minimum of ADR-0054 can be revisited.
- **Speed and memory** on a 16 GB Mac and on an 8 GB one, compared with Qwen 3.5 4B.
- **Download:** size, fixed URL and SHA-256 (network rule no. 1).

## Decision
To be made after the tests. If MiniCPM is better than Qwen 3.5 4B in quality and JSON reliability for the same memory, it replaces it; if it is better only at some tasks, it is added; otherwise, it is discarded.
