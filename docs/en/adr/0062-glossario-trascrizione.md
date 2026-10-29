# ADR-0062 — Transcription glossary

- Status: accepted
- Date: 2026-10-21
- Spec references: sec. 7 (transcription); ADR-0023; "transcription quality" memory; test of 2026-10-21 (`docs/benchmarks/2026-10-21-sintesi-e-glossario.md`)

## Context
Real transcripts get names wrong above all: companies, acronyms, people. These errors also end up in summaries and key points.

## Decision
- **The glossary:**
  - **Settings › Transcription › Glossary**: names and terms separated by commas;
  - for each call IAGO adds on its own the project, client, stream and project contacts.
- **Whisper** receives the glossary as *initial prompt*:
  - unique terms, at most about 200 characters, because a long text makes Whisper repeat the prompt during silences;
  - in `TranscriptionOptions.vocabulary` and `vocabularyPrompt`.
- **Parakeet** does not use it for now (FluidAudio has a different system, to be evaluated).
- `iago-bench --vocabulary` is used to compare with and without the glossary.

## Consequences
- **Test outcome:**
  - on a 65-minute call it invented nothing and discarded fewer hallucinations (from 4 to 2);
  - on a synthetic sentence it corrected 2 names out of 4.

  It helps, but it is not decisive: the in-depth transcription test remains on the list.
