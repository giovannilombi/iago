# ADR-0094 — Voice recognition on, simpler speaker names, your name

- Status: accepted
- Date: 2026-11-05
- Amends: ADR-0073 (recognizing voices) and its 1.2.4-beta amendment
- References: ADR-0049 (suggestions), ADR-0058 (data), FR-41 (renaming speakers); user request of 2026-11-05

## Context
- Voice recognition was off by default (ADR-0073). Someone who did not turn it on named speakers, but IAGO saved no voice print: *Known voices* stayed empty and the next calls proposed no names.
- A speaker's name applied only with Return or the ⏎ button (1.2.4-beta amendment). The unconfirmed field was red and looked like an error. Leaving the field with a click left the name pending, and names already known were not suggested while typing.
- The user's name in transcripts (*Your name*) is chosen at first launch. The setting was only in General, the user could not find it, and changing it did not touch calls already transcribed.

## Decision
- **Voice recognition on by default.** Settings › Voices turns it off: in that case the saved value is `0`, and no value means "on". The other rules of ADR-0073 stay the same: prints encrypted with the item's key, never to Claude, exports or sharing; suggestions to confirm; deleting one voice or all of them. CLAUDE.md, where it says "only with Settings › Voices on", stays true too: it is on until the user turns it off.
- **A speaker's name:**
  - while typing, IAGO suggests the names it knows: people, speakers already named and *Attendees*. First those that start with the typed text, then those that contain it, without the names already used in the call;
  - the name is saved with Return, the ✓ button **or by leaving the field**. Before saving it IAGO asks the same questions as before: similar names, same name as another speaker;
  - the unsaved field has a border in the accent colour, not red, with the line *Return or ✓ to save, Esc to cancel*.
- **Calls transcribed without prints:** if recognition is on but the call has no prints, because it was transcribed while off, a line under the names says to use *Transcribe again* to let IAGO learn the voices.
- **Your name:** it is also at the top of Settings › Voices, besides General. It applies with Return, *Save* or by leaving the field. Calls where the user's voice still has the previous name take the new one (`Archive.renameMe`). If in a call the user gave their own voice another name, that one stays.

- **"You":** next to the user's voice, in the transcript and in the speaker names, the *You* mark appears. It applies to the microphone's voice in a call recorded with IAGO and, in an imported file, to the speaker who has the user's name. Hovering over it with the mouse tells which of the two cases it is.

## Consequences
- Prints are collected from calls transcribed from now on; earlier ones need *Transcribe again*.
- A name typed and left with a click is no longer lost and no longer stays pending.
- Biometric data on by default: the note in Settings › Voices explains what is saved and where, and one click turns it off.
