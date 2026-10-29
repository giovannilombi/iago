# Quality and measurements

## Automated tests
301 tests in the packages, with Swift Testing, all green on every PR:

| Package | Tests |
|---|---|
| IAGOStore | 109 |
| IAGOCapture | 48 |
| IAGOTranscription | 29 |
| IAGOIngest | 22 |
| IAGOIntelligence | 32 |
| IAGOMCP | 20 |
| IAGOCore | 15 |
| IAGOExport | 10 |
| IAGOEngine | 15 |
| IAGOSync | 1 |

- The audio pipeline uses **synthetic** fixtures (`say` voices), never real recordings.
- The Vision OCR tests run only locally: on GitHub runners Vision hangs (see [Development](./sviluppo#ci)).
- The MLX engine is tested with `scripts/test-engine.sh` and with the `-IAGOEngineBench` bench.

## Manual tests
- [Tester checklist](/en/prove-tester): the ordered list, designed for people who do not know the app.
- Each tester has a GitHub issue with the tests as checkboxes; problems become separate issues.

## Measurements
- [Transcription, phase 0](/en/benchmarks/2026-10-phase0): Whisper and Parakeet on 2 h 44 min of real calls.
- [Summaries and glossary](/en/benchmarks/2026-10-21-sintesi-e-glossario): Qwen 9B and Gemma 12B on real calls, Whisper glossary.

The measurements report only numbers and observations: the content of the calls stays on the Mac of whoever made them.

## Development history
- [Phase 0](/en/phase-0): two-track capture and test of the transcription engines.
- [Phase 1](/en/phase-1): archive, transcription, organization, guided setup.
- [Phase 2](/en/phase-2): search, decisions, hierarchy, notes, emails, exports.
- [Phase 3](/en/phase-3): Claude via MCP, local engine, semantic search, suggestions, Ask, summaries.
