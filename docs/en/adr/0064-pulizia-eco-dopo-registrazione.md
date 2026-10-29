# ADR-0064 — Echo cleanup after recording

- Status: rejected (2026-10-21)
- Date: 2026-10-21
- Spec references: sec. 6 (capture), 7 (transcription); ADR-0002 (two tracks), ADR-0053 (withdrawn); user request 2026-10-21

## Context
- Without headphones the microphone hears the speakers: the other participants' voices come back on the user's track, delayed.
- macOS echo cancellation during the call (ADR-0053) was withdrawn, because it left Teams without a microphone.
- IAGO, however, has an advantage that call apps do not have: the **system track**, that is, exactly what came out of the speakers, recorded on the same clock as the microphone. The reference for removing the echo is perfect and already aligned.

## Proposed decision
- **When:** once recording is finished, the microphone track is cleaned using the system track as a reference. It is a queue job (QoS `.utility`, one at a time, never during a recording), before transcription.
- **Never during the call:** the call app's microphone is not touched.
- **The original remains:** the cleaned track is a copy. It is used for transcribing and listening, and you can always go back to the original.
- **Prototype engine:** the **SpeexDSP** echo canceller (block frequency-domain MDF, plus residual echo suppression), BSD license, included as C source.
  - If quality is not enough, switch to **WebRTC AEC3**, more effective but C++ with heavy dependencies.
- **Can be turned on and off** in Settings › Audio, as requested by the user. The default value is decided after the measurements.

## To be measured with the prototype
- **How much echo it removes** on a real recording without headphones: level of the other participants' voices on the microphone track, before and after.
- **How well it preserves the user's voice** when people talk over each other (synthetic test with a near voice and a far voice).
- **Time and load for an hour-long call.** Estimate: from a few seconds to about a minute, on one core, versus about 3 minutes for Whisper transcription.

## Consequences
- No risk for the call in progress: everything happens afterwards, on the files.
- A new dependency, to be recorded in `docs/licenses.md`.

## First prototype measurement (2026-10-21)
- **Synthetic test** (automated test `EchoCleanerTests`, with echo at 47 ms plus two reflections and a stretch where people talk over each other):
  - echo reduced by **19 dB**;
  - near voice preserved at **95%**;
  - 20 s cleaned in 0.09 s.
- **Real 31-minute call** without headphones (the user's microphone track, with the system track as reference):
  - cleaned in **7.9 s**, that is about 15 s per hour and 234 times faster than real time;
  - a single core, about 490 MB peak;
  - how much the microphone follows the speaker audio drops from 0.74 to 0.32 (0 = no echo).
- **Listening:** on a 40-second clip, original and cleaned, the user preferred the original (see below).
- **Tools** used for the test (`iago-bench --aec`, track extraction in Debug): removed together with the prototype.

## Outcome: rejected (2026-10-21)
- **On listening** to the same clip, original and cleaned, the user found the **original much better**. The numbers (less echo) are not enough if the user's voice gets worse.
- **Decision:**
  - the cleanup is not done;
  - SpeexDSP, `EchoCleaner`, the `iago-bench --aec` test and track extraction have been removed from the code;
  - for echo there remains the **transcription filter**, which discards system track sentences repeated on the microphone (ADR-0002), plus the advice to use headphones.
- **Reason not to insist:** it is not a priority, and every attempt requires listening tests by the user. A possible test with WebRTC AEC3 remains possible in the future, but only with a new request.
