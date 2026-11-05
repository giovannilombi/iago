# ADR-0073 — Recognizing the same voices across different calls

- Status: accepted, amended by ADR-0094 (on by default, speaker names)
- Date: 2026-10-27
- References: ADR-0006 (FluidAudio, diarization), ADR-0028 (per-item keys), ADR-0049 (suggestions), ADR-0058 (data), ADR-0070 (who produced a result); user request of 2026-10-27

## Context
- Each call has voices "Speaker 1", "Speaker 2"… that the user renames by hand or with an engine suggestion. The same people come back call after call.
- FluidAudio's diarization already computes a fingerprint for each voice: 256 numbers, a WeSpeaker *embedding*. IAGO used it only within the call and then threw it away.
- The voice fingerprint is **biometric data** (GDPR art. 9): it must be handled with more care than the rest.

## Decision
### What it does
- **Settings › Voices**, *Recognize voices from one call to the next*: **off by default**.
- When on, with every transcription IAGO keeps the fingerprint of the speakers on the other side, or of the whole imported file, who speak at least 10 seconds. Your own track ("Me") has no fingerprint; the room voices (ADR-0031) do not either, for now.
- **Naming a speaker teaches the voice**: the fingerprint is tied to that person. This applies to a name typed by hand and to a confirmed suggestion. If you then rename it to another name, the fingerprint moves to that one; if you go back to "Speaker 2", it is untied.
- **In later calls**, a speaker still without a name who resembles a known voice receives a suggestion: «Speaker 2 becomes Marco», with the line «Recognized by voice (82% similarity)». **It never assigns on its own**: it is confirmed or discarded like the other suggestions (ADR-0049). On confirming, the other name suggestions for the same speaker are discarded.
- **Threshold:** cosine similarity at least 0.60 and at least 0.05 above the second-closest voice; a voice goes to at most one speaker per call, and a person already named in the same call is not suggested. Values to be tuned with real calls (`Archive.voiceThreshold`, `voiceMargin`).
- A call already transcribed before activation learns the voices with **Retranscribe**: speakers who already have a name are tied right away to their voice.

### Data (migration `v20-voices`)
- `item_voice`: one row per speaker of a call, with the fingerprint **encrypted with the item's key** (AES-GCM, bound to item and speaker), the seconds of speech and the voice it is tied to.
- `voice`: only id and name (unique, case-insensitive). **A person's fingerprint is not saved**: it is computed on the fly as the average of the fingerprints from their calls, weighted by seconds of speech.
- This way:
  - deleting a call permanently (crypto-shredding) removes its share from every fingerprint;
  - a voice with no calls left disappears on its own;
  - **Delete** on a voice deletes the voice and the fingerprints of the calls it came from (the names in the transcripts remain);
  - **Delete all voices** (in three steps: warning, type DELETE, final confirmation) also deletes the fingerprints of unnamed speakers.
- Turning the switch off stops learning and recognition; saved voices remain until the user deletes them, and the panel says so.
- Suggestions have `origin = voice` (ADR-0070) and the similarity as a percentage.

### What it does not do
- Fingerprints **never** go to Claude (no MCP tool reads them), into exports, into Obsidian or into future sharing (no row in the change log). They remain only in the encrypted backup, because they are part of the archive.
- No additional model: the fingerprint comes out of the diarization that is already done.

## Consequences
- Negligible space: about 1 KB per speaker per call. Negligible time: comparing against dozens of voices takes less than a millisecond.
- With compressed audio, several people on a room microphone or similar voices, recognition can be wrong; this is why it only suggests.
- Quality depends on voice separation: if diarization merges two people, the fingerprint mixes them too.

## Amendment of 2026-10-30 (1.2.4-beta)
- **The name is confirmed:** it applies only with Return or with the ⏎ button. Before, a name typed and left with a click was lost; now the unconfirmed field is red and the text stays while IAGO is open.
- **Similar names:** before applying a name IAGO asks whether it is an already known person with a similar name. It considers typos, one name inside the other and Italian nicknames («Lello» and «Antonello»). A «yes» answer stays as an alias (`name_alias`) and next time the known name is suggested right away. It only asks: it never renames by itself.
- **Join and Separate:** the same name for two speakers of the same call offers to join them, because diarization often splits one person in two. The joined speaker takes the other's name and voice (`item_speaker.merged_into`), and so the person's fingerprint is made with all their sentences. «Separate» puts it back as it was, useful when they were two people after all. The saved transcript does not change.
- **Before the summary:** with speakers still generic, *Generate summary* and *Regenerate* ask whether to name them first or go ahead, noting that the summary can be regenerated. Automatic summaries go ahead without asking.

## Change of 2026-10-30 (1.2.8-beta)
- The separated **room voices** too (ADR-0031, «Room 2», «Room 3»…) have their voice print and are recognized in later calls. The user's voice («Me») stays without one.
