# Transcription

Everything happens on the Mac (ADR-0005), in the job queue, one item at a time.

## Pipeline
1. **Decoding** of the tracks and resampling to 16 kHz mono.
2. Silero **VAD** (via FluidAudio) and splitting into speech blocks (ADR-0006).
3. **Recognition** with the chosen engine.
4. pyannote/WeSpeaker **diarization** (FluidAudio) on the system track; the microphone track is "Me". Several people in the same room are separated on the microphone too (ADR-0031).
5. **Segmentation by speaker:** whisper word timings, segments split at speaker changes and broken sentences stitched back together.
6. **Merging** of the two tracks on the timeline and **echo filter:** microphone sentences that repeat those of the system track are discarded.
7. **Indexing** of the segments for search.
8. **Voices** (only if enabled in Settings › Voices, ADR-0073): see below.

## Recognizing voices (ADR-0073)
- Diarization gives a **WeSpeaker voiceprint** for each speaker (256 numbers, `DiarizationResult.speakerDatabase`), renumbered like the speakers (`TranscriptPostProcessing.normalizeVoices`). The pipeline returns it in `Output.voices`, with the seconds of speech, for the system track or for the imported file; the microphone ("Me") and the room voices do not get one.
- After transcription `TranscriptionService` saves it (`Archive.storeVoices`, at least 10 s of speech) and looks for known voices (`Archive.voiceMatches`): cosine similarity ≥ 0.60 with the average of the person's voiceprints, at least 0.05 above the second voice, one person per speaker. Matches become `person` suggestions with `origin = voice`.
- `Archive.renameSpeaker` binds the call's voiceprint to the name (or unbinds it, if it goes back to generic). An error in voices does not make the transcription fail.
- **Speaker names** (`App/Sources/UI/ItemDetailView.swift`, `SpeakerNames`; `IAGOStore/SpeakerNames.swift`):
  - the name applies only with Return or ⏎; the unconfirmed text sits in `AppModel.speakerDrafts` (in memory, per item) and the field is red;
  - before applying it, `Archive.similarPersonNames` searches among people and named speakers (`knownPersonNames`). First comes the alias chosen by the user (`name_alias`, by normalized form), then `PersonNameMatcher`: a typo in long names, one name inside the other, a table of Italian nicknames, a short form at the start or end («Ale», «Sandro», «Nello»). A word in common alone is not enough;
  - **Join** (`Archive.mergeSpeaker`): `item_speaker.merged_into` points to the speaker of the same call and the label becomes its own. So transcript, summary and exports stay unchanged, and the voiceprint goes to the same voice. Renaming the target speaker also renames the joined ones. **Separate** (`separateSpeaker`) puts back the transcription's label. `transcript.json` is never rewritten;
  - before *Generate summary* and *Regenerate*, `AppModel.unnamedSpeakers` (generic labels, excluding `me` and the joined ones) makes IAGO ask whether to name them first; «Name them first» (`AppModel.namingSpeakersFor`) opens the transcript, brings it into view and puts the cursor in the first unnamed field.
- Costs: no extra model, about 1 KB per speaker, comparison under a millisecond.

## Engines (ADR-0023)
| Engine | Implementation | Measured speed | Notes |
|---|---|---|---|
| **Whisper large-v3-turbo** (default) | whisper.cpp 1.9.2, Metal, beam search 5, Italian forced | 19× real time | more accurate on names and English terms |
| **Parakeet TDT 0.6B v3** | FluidAudio, CoreML on the Neural Engine | 87× real time | faster, more errors on names |

- Diarization takes a few seconds per call (about 300× real time).
- Measurements on 2 h 44 min of real calls, M3 Pro: [phase 0 benchmark](/en/benchmarks/2026-10-phase0).
- The models (about 1.6 GB) are downloaded on request from fixed URLs with SHA-256 verification.

## Glossary (ADR-0062)
- Names of people, clients and project terms become Whisper's **initial prompt** (at most 200 characters).
- Parakeet has no prompt: the glossary applies only to Whisper.
- Measurement: [summaries and glossary](/en/benchmarks/2026-10-21-sintesi-e-glossario).

## Tools
- `iago-bench` (package `IAGOTranscription`) compares engines and options on local audio files; the results stay in `bench-out/`, never in the repository.
- Test fixtures are synthetic (`scripts/make-fixtures.sh`, `say` voices).
