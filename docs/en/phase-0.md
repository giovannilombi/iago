# Phase 0 — Capture spike: status

Goal (spec 18): eliminate the technical risk on two-track capture, microphone "in use by the call app", robustness and choice of the ASR engine.

## What's there

| Component | Where | Notes |
|---|---|---|
| Menu bar (`NSStatusItem`) | `App/Sources/StatusItemController.swift` | left-click: menu with status; right-click (or Control-click) start/pause/resume; menu: status + duration + mic, Pause/Resume, Stop, New recording, Microphone (automatic/manual), Open recordings folder, Quit with confirmation; attention icon for silent track (FR-16) |
| System process tap | `IAGOCapture/SystemAudioTap.swift` | global tap that excludes IAGO, private aggregate **with no physical sub-devices** (independent of the output). **The tap delivers no buffers while no app is playing audio**: the gap becomes silence and the track is completed at stop; the tap is rebuilt only if it stays idle while another process is playing |
| Microphone that follows the call | `MicDeviceResolver.swift` (pure logic) + `CaptureEngine.swift` | Core Audio process objects (`IsRunningInput`, input `Devices`, bundle ID), call-app priority, fallback to the default input, manual override; listener + 2 s polling |
| Alignment | `TrackAligner.swift`, `SessionTimeline.swift` | common host time; gaps → silence, overlaps trimmed, pauses excluded from the timeline; resampling to 48 kHz |
| Incremental writing | `CAFFileWriter.swift`, `TrackWriter.swift` | CAF Float32 with data size −1 during recording; write every 0.5 s, `fsync` every 2 s, periodic flush even with no buffers |
| Finalization and recovery | `SessionFinalizer.swift` | mono AAC per track + mix; idempotent; interrupted sessions finalized at launch with a notification. **Not encrypted** (phase 1) and in `Recordings/` instead of `Items/` |
| Controller | `RecordingController.swift` | actor, state machine; "New recording" swaps the session at the same host time without stopping capture |
| Sleep | `AppDelegate.swift` | automatic pause + prompt on wake (FR-15) |
| Mark moment (addendum, FR-05) | menu bar | bookmark 5 s before the click, ADR-0024 (⌥ to add a note), feedback on the icon; saved in `session.json` as a `bookmark` marker, to be imported into the `marker` table in phase 1 |
| Transcription (benchmark) | `IAGOTranscription` | `TranscriptionEngine` protocol, `WhisperCppEngine`, `ParakeetEngine`, FluidAudio VAD + diarization, sec. 7.2 pipeline (VAD chunking, hallucination filter, echo filter, speaker assignment), `transcript.json` |
| Tools | `iago-spike`, `iago-bench`, `scripts/` | levels, drift, audio process table; ASR benchmark; `say` fixtures; model download with SHA-256 |

Automated tests: 43 in `IAGOCapture`, 8 in `IAGOCore`, 22 in `IAGOTranscription` (`scripts/test-packages.sh`).

## Acceptance criteria

| Criterion (spec 18) | Status | Evidence |
|---|---|---|
| 10-min test call on Teams, Zoom, Meet: both tracks present and audible | ✅ | Teams 10:42, Meet Chrome 10:20, Meet Safari 3:41, Zoom app 5:48 and browser 1:56 (2026-10-12; reduced duration for Zoom/Safari agreed with the user). Checklist rows 1–4 |
| AirPods ↔ built-in microphone mid-call without losing the voice | ✅ | Bluetooth headphones ↔ built-in microphone on all apps (2026-10-12), ADR-0025. Checklist row 5 |
| Speakers ↔ headphones without losing the remote audio | ✅ | Teams, output headphones → speakers → headphones with no gaps (2026-10-12). Checklist row 6 |
| Drift between tracks < 50 ms | 🟡 partial | 3.1 ms over 3 min with `iago-spike drift`; 2-hour test postponed by the user (checklist row 13, `beeps.wav` ready) |
| `kill -9` → session recovered at restart | ✅ | 8.44 s recovered out of ~8.5 s (2026-10-11); live 25.07 s (2026-10-12) |
| Benchmark report + ADR B | ✅ | `docs/benchmarks/2026-10-phase0.md`, ADR-0023 accepted (2026-10-12) |

## Open questions

1. **Real-time echo cancellation (spec 6.3)** not yet tested. Mic capture uses a direct HAL IOProc, while Apple's voice processing requires `AVAudioEngine`/VPIO on the input device, with the known effect of lowering the volume of other apps ("ducking"). Proposal: in phase 0 rely on the echo filter in transcription (verified on fixtures with simulated echo); VPIO to be evaluated in a dedicated spike, possibly as an option.
2. **Microphone kept open while paused.** While paused, capture continues (discarding the buffers) to resume with no latency: the orange microphone indicator stays on. To be decided whether to release the devices while paused.
3. **Fallback to the default input with AirPods.** If no app is using the microphone and the default input is the AirPods, opening them forces the Bluetooth "call" profile (reduced audio quality). To be evaluated: prefer the built-in microphone when no call is active.
4. **Allocations on the real-time thread.** Closed in phase 1: the IOProcs are created with a dispatch queue, so the callbacks don't run on the real-time thread and allocation is allowed.
5. **FluidAudio downloads models automatically** from HuggingFace. In the app `ModelHub.offlineMode` must always be enabled and the models must be managed by the `ModelManager` (spec 7.5).
6. **Mute in the call app.** IAGO opens the microphone directly (HAL IOProc), so the software mute of Teams, Zoom or Meet doesn't silence the mic track: the user's voice is recorded even when muted. Hardware mute (headset button, input volume at zero) does silence it. Risk: if during mute the call app releases the microphone, the resolver falls back to the default input, which may be a different device. Proposal: for the whole session stay on the last microphone used by the call (new ADR extending ADR-0004). Verification: checklist row 4c.
