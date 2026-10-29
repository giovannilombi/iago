# ADR-0006 — VAD and diarization with FluidAudio

- Status: accepted
- Date: 2026-10-11
- Spec references: sec. 7.1, 7.2, 17.6

## Context
VAD (to limit ASR to speech regions and reduce Whisper hallucinations) and diarization are needed. The options evaluated are FluidAudio (Swift/CoreML, Neural Engine) and sherpa-onnx (C++/ONNX).

## Decision
FluidAudio for VAD and diarization. In recordings, diarization is applied **only** to the system track (the mic track is "Me"); in imports, to all the audio.

## Consequences
- Native Swift integration via SPM, running on the Neural Engine.
- Dependency on a relatively young project: pinned version, license in `docs/licenses.md`.
