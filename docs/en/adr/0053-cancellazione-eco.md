# ADR-0053 — macOS echo cancellation on the microphone

- Status: withdrawn (2026-10-21)
- Date: 2026-10-20
- Spec references: sec. 6 (capture); ADR-0002 (two tracks), ADR-0004 (microphone), ADR-0031; user request 2026-10-20

## Context
Without headphones, the microphone also picks up the speakers. The other participants' voices thus end up in the recording twice: clean on the system track, and delayed and "metallic" on the microphone track. ADR-0002 already anticipated this ("echo cancellation and a filter in transcription are needed"), but the decision had remained open.

macOS has built-in echo cancellation (*voice processing*, the `VoiceProcessingIO` unit), the same one used by FaceTime and many call apps.

## Decision
- **Setting** in Settings › Audio › Microphone: "macOS echo cancellation on the microphone", **on by default** (the user's choice after the test). It applies from the next recording.
- **How it works:**
  - with the setting on, the microphone track goes through `VoiceProcessingIO` (`VoiceProcessingMic.swift`) on the same microphone chosen by IAGO (ADR-0004);
  - each buffer carries its arrival time, as today, so the tracks stay aligned;
  - IAGO plays nothing back;
  - other apps are lowered as little as possible (*ducking* at the minimum level). macOS does not allow turning it off completely: Teams sounds about 8 dB quieter while IAGO is recording;
  - the hidden devices macOS creates for cancellation (`VPAUAggregateAudioDevice…`) do not appear among the microphones.
- **If cancellation does not start** on that microphone, IAGO records the normal microphone and notes it in the session timeline. The recording is never lost.
- **The system track does not change.**

## Consequences
- Without headphones, the microphone track contains much less of the other participants' voices: transcription does not duplicate them and diarization makes fewer mistakes.
- Your own voice may sound a bit more "processed", as in a FaceTime call. With headphones cancellation is not needed, but it does no harm.
- Echo cancellation adds a few milliseconds of processing. It must be verified that the drift between tracks stays below 50 ms (2-hour acceptance test).

## Test of 2026-10-20 (user's Mac, MacBook speakers, 8 s test voice)
| | speaker voice in the microphone, relative to the original | system track |
|---|---|---|
| normal microphone | −0.9 dB | −15.2 dB |
| cancellation, minimum ducking | −29 dB, just above the room noise | −23.2 dB (−8 dB) |
| cancellation, maximum ducking | below the noise | −65 dB (−50 dB) |

- Minimum *ducking* remains 8 dB, and the user accepts it.
- The microphone track with cancellation appears to arrive about 35-40 ms later than the normal microphone. This is a single measurement, on a weak residue: it must be confirmed in the drift acceptance test. If confirmed, it is compensated with a fixed offset.

## Withdrawal (2026-10-21)
- **Problem found by the user:** with cancellation on, during IAGO recordings **Teams was left without a microphone**. Two voice processing units were working on the same microphone, Teams' and IAGO's: macOS creates an intermediate device (`VPAUAggregateAudioDevice`) and the call app loses its input.
- **Why the test had not shown it:** it had been done with audio played by `afplay`, with no call app open.
- **Decision:** the feature is **removed**, code and setting. An option that takes the microphone away from the call app makes no sense. IAGO goes back to reading the microphone as it is (HAL IOProc) and keeps excluding the call apps' `VPAUAggregate` devices from the microphones.
- **For echo without headphones:**
  - today: headphones, plus the residual echo filter in transcription, which was already there (ADR-0002);
  - a possible future path, to be proposed in a new ADR: clean the microphone track **after** recording, using the system track as a reference, without touching the microphone during the call.
