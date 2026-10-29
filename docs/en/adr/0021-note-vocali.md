# ADR-0021 — Voice notes are normal notes; the audio is not kept

- Status: accepted
- Date: 2026-10-11
- Spec references: v1.4 sec. 3.22 (FR-210…219), 7.7; addendum C.2, H.21

## Context
Dictating a note is faster than writing it, but keeping the audio would add sensitive data with no value once transcribed.

## Decision
A voice note is a note with `input = 'voice'`. The audio (microphone only) is an input method: it is transcribed immediately with the same `TranscriptionEngine` as calls (preferring the fastest engine) and deleted as soon as the note is saved and verified. If transcription fails, the temporary audio remains until the user retries or discards it. Voice notes do not create assets and are not available during a call recording.

## Consequences
- High-priority transcription jobs, ahead of call jobs.
- Temporary audio in `tmp/voice-notes/`, cleaned up at startup.
