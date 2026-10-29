# ADR-0031 — "More people in the room" option

- Status: accepted (user request, 2026-10-12)
- Date: 2026-10-12
- Spec references: sec. 7.2, FR-41; ADR-0002, ADR-0006

## Context
The pipeline assigns the whole mic track to the "Me" speaker and diarizes only the system track (spec 7.2, ADR-0006). In the block 3 test, two people in the same room, both on the Mac's microphone, all ended up under "Me".

## Decision
- Per-item option **"More people in the room"**, chosen in the post-recording panel or in the detail view when transcribing or re-transcribing (off by default).
- With the option on, the mic track is diarized like the system track. The voice with the most speech is "Me" (`me`); the others become `r2`, `r3`… labeled "Room 2", "Room 3"…, renamable like the other speakers (FR-41).
- The echo filter is applied to the mic segments already split by speaker.
- Nothing changes for imported items (a single track): they are already fully diarized.

## Consequences
- Deviation from spec 7.2 step 3 and from ADR-0006 only when the option is on.
- The main voice is chosen by duration: if the user speaks less than the others present, it must be renamed by hand.
- Extra diarization on the mic track: a few seconds per hour of audio.
