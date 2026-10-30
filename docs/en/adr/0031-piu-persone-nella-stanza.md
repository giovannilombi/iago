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

## Change of 2026-10-30 (1.2.8-beta)
User request: often you do not know beforehand that there will be several people, and starting the recording must stay immediate.
- **IAGO decides by itself** (`RoomMode.auto`, the new default): the microphone is always diarized. If the system track has less than 10 s of speech it is a meeting in person and the voices with at least 20 s of speech are separated by themselves. With a call they stay under «Me», because the call's echo confuses things, and the card offers *Separate the voices*, which transcribes again with the option on.
- Voices shorter than 20 s stay with the user: usually they are the user's own voice split in two, or a noise.
- **During the recording:** *Several people here in the room* in the icon's menu; the automatic transcription and the panel after Stop use it.
- **Present** (migration `v24-attendees`): the user can write who was there, in the panel after Stop or later in the card. The names are offered for the speakers still without a name and go into the exports; they are not tied to the voices until the user gives a name.
- The separated room voices have their own voice print (ADR-0073).
- Nothing changes for people connected remotely: the system track was already split by voice, also with several people on the same computer.
- Recording the microphone alone, without the Mac's audio, is left for later: with the Mac's audio silent the result is the same.
