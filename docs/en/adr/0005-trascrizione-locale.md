# ADR-0005 — Transcription exclusively local, interchangeable engines

- Status: accepted
- Date: 2026-10-11
- Spec references: sec. 3.6 (FR-50), 7.1, 17.5

## Context
Calls contain confidential information. A cloud fallback, even an occasional one, would violate the principle "nothing leaves the Mac without explicit action".

## Decision
Transcription happens only locally, with no cloud fallback at all. The engines sit behind the `TranscriptionEngine` protocol: `WhisperCppEngine` (initial default, large-v3-turbo, Italian forced with an "automatic" option) and `ParakeetEngine` via FluidAudio. The final default is set with an ADR after the phase 0 benchmark (open decision B).

## Consequences
- Models to download (only on user action, fixed URLs, SHA-256) and to manage on disk.
- Performance tied to the hardware; goal: clearly faster than real time on an M3 Pro.
- Changing engine does not affect the rest of the app.
