# ADR-0023 — Default ASR engine: whisper.cpp large-v3-turbo

- Status: accepted (2026-10-12, after the user's evaluation)
- Date: 2026-10-11
- Spec references: sec. 7.1, 17.B; ADR-0005; `docs/benchmarks/2026-10-phase0.md`

## Context
The spec leaves open the choice of the default engine between whisper.cpp and Parakeet (FluidAudio) until the phase 0 benchmark on real calls. The benchmark on 5 real calls (164 min, M3 Pro) gives whisper large-v3-turbo at 19× real time and Parakeet v3 at 87×. Qualitatively, whisper is better on English terms and product names, on punctuation and at chunk boundaries, and makes the echo filter in transcription more effective.

User's evaluation (2026-10-12): whisper is more faithful in the text, Parakeet seemed better at speaker attribution. Diarization is the same for both (FluidAudio): the difference came from segmentation. IAGO assigned a single speaker to each whisper segment (up to 28 s), while for Parakeet it builds per-sentence segments from token timings. Public benchmarks on Italian FLEURS confirm whisper's advantage on text (WER: large-v3 2.31% versus 3.00% for Parakeet v3 in the NVIDIA paper; turbo 2.77% versus 3.02% on the Handy leaderboard).

## Decision
- Default: `WhisperCppEngine` with `large-v3-turbo`, Italian forced, beam search 5, only on VAD regions.
- Per-word timings from whisper.cpp (`token_timestamps`). Two-step segmentation, shared by the engines:
  1. `splitBySpeaker`: each whisper segment is split where the speaker changes, assigned word by word; runs shorter than 1.5 s are merged into the neighbor and the cut snaps to punctuation within 2 words (diarization and word timings are imprecise at the edges);
  2. `joinSentences`: consecutive segments of the same speaker are joined if the sentence is not finished (pause ≤ 0.8 s, duration ≤ 20 s).
  Stitching sentences before splitting by speaker shifted the cuts by 1–2 words: the order is binding.
- whisper.cpp DTW alignment tried (`alignedWords` option): no more precise than the heuristic timings on synthetic voices (constant delay ~0.2 s) and incompatible with flash attention; not used.
- Alternative selectable in the settings: `ParakeetEngine` v3 ("fast transcription").
- VAD and diarization remain FluidAudio for both (ADR-0006).

## Consequences
- 1.6 GB model to download during onboarding; transcription of 1 hour in ~3 min on an M3 Pro.
- Parakeet remains available without changing the pipeline (`TranscriptionEngine` protocol).
- Refinement of the segmentation possible in phase 2 without changing engine (parameters `minSpeakerRun`, pause, maximum duration).
- To be re-evaluated if a more accurate multilingual Parakeet model comes out (e.g., `ultra`, not yet tested) or with two-track recordings.
