# ADR-0002 — Two separate tracks, mix only for listening

- Status: accepted
- Date: 2026-10-11
- Spec references: sec. 3.2 (FR-10), 6, 7.2, 17.2

## Context
A mixed recording loses the information about who is speaking: diarization on a mix is less reliable and does not distinguish the user from the others. With separate tracks the user's voice is known by construction.

## Decision
Every recording produces two synchronized tracks: `systemTrack` (audio output from all apps, excluding IAGO) and `micTrack` (microphone in use in the call). The mic track is always the "Me" speaker. A mix is generated at finalization only for listening; the transcription pipeline works on the separate tracks.

## Consequences
- Diarization is needed only on the system track; the "Me" speaker is certain.
- Precise synchronization is required (host time, filling gaps with silence, drift < 50 ms).
- With speakers, the mic track picks up echo: echo cancellation and a filter in transcription are needed.
- Disk space roughly three times that of a single track (mic + system + mix).
