# Capture test checklist (manual)

Capture integration tests (spec 16.4, phase 0 acceptance in sec. 18). To be repeated at every change to `IAGOCapture` and before closing a phase. The recordings produced **are not committed**.

## Preparation

- Signed Debug build: `scripts/bootstrap.sh && xcodebuild -project IAGO.xcodeproj -scheme IAGO build`.
- Permissions granted: Microphone and System Audio Recording (System Settings › Privacy & Security).
- Tools: `swift build -c release --product iago-spike` in `Packages/IAGOCapture`.
  - `iago-spike processes` — shows which microphone IAGO would follow and why.
  - `iago-spike levels <file>` — RMS levels per second (silent track = `-120`).
  - `iago-spike make-beep beeps.wav <minuti>` and `iago-spike drift <cartella>` — drift measurement.
- Finished recordings are in `~/Library/Application Support/IAGO/Recordings/<itemId>/` (`mic.m4a`, `system.m4a`, `mix.m4a`, `session.json`).

## Result for each call

The system tap is global (all processes except IAGO): native apps and browsers are captured the same way. The browser rows are needed because Meet exists only in the browser and browsers use helper processes with different bundle IDs, which the microphone resolver must recognize.

For each row: both tracks audible (`levels` without long `-120` stretches when someone is speaking), the user's voice present in `mic.m4a`, remote voices in `system.m4a`, no gaps.

| # | Scenario | How | Expected | Result | Date | Notes |
|---|---|---|---|---|---|---|
| 1 | Teams (native app) 10 min | test call, recording from the menu bar | two audible tracks; `processes` shows `com.microsoft.teams*` with the right mic | ✅ | 2026-10-12 | real call 10 min 42 s (item `01a12f34…`): system track with no gaps; mic at -120 only for 5 isolated s with BT headphones in silence; 2 correct `deviceChange` |
| 2 | Zoom (native app) 10 min | same | `processes` shows `us.zoom.*` | ✅ | 2026-10-12 | app (`us.zoom.xos`) 5 min 48 s: mic 0 s at -120; headphones connected/removed followed (callApp), mute ok. Zoom in the browser (1 min 56 s) also ok. 10-min duration verified on Teams and Meet Chrome (agreed with the user). Zoom sends true zeros in silences |
| 3 | Meet in Chrome 10 min | same | `processes` shows a `com.google.Chrome*` process | ✅ | 2026-10-12 | 10 min 20 s: process `com.google.Chrome.helper`; mic with no gaps; mute ok; headphones chosen in Meet and removed followed (removing them IAGO switches to the MacBook at once, Meet stays without mic ~5 s). **Bug**: with Meet on "default" and headphones just connected Chrome lists 2 inputs and IAGO takes the first (MacBook) instead of the headphones in use → proposal ADR-0025. Silences in the system track = no remote audio |
| 4 | Meet in Safari 10 min | same | `processes` shows `com.apple.WebKit*`/Safari | ✅ | 2026-10-12 | 3 min 41 s (10-min duration verified on Teams and Meet Chrome, agreed with the user): process `com.apple.WebKit.GPU`; mute: Safari keeps the mic, voice recorded; headphones chosen in Meet and removed: followed. Connecting the headphones (Mac default) IAGO flips 2 times in 4 s between headphones and MacBook; ~2 s of mic at -120 removing the headphones (Meet was without mic too) |
| 4b | Teams in the browser 10 min (optional) | same, from teams.microsoft.com | as row 3/4 | | | |
| 4c | Mute in the call app | during a call (rows 1–4) mute the microphone in the app for ~30 s while speaking, then unmute it | the user's voice present in `mic.m4a` even during the mute; note whether `session.json` has a `deviceChange` (the app released the microphone) | ✅ Teams | 2026-10-12 | Teams keeps the mic open during mute; voice recorded; no mic change. To be repeated on Zoom and Meet |
| 5 | Mic change AirPods ↔ built-in mid-call | change the input in the call app | `session.json` has a `deviceChange` marker; the user's voice present before and after | ✅ Teams | 2026-10-12 | CMF Buds Pro 2 ↔ MacBook mic: two `deviceChange`, no gap at the switch |
| 6 | Output change speakers ↔ headphones | change the system output during the call | continuous remote audio in `system.m4a` | ✅ Teams | 2026-10-12 | Teams output headphones → speakers → headphones: continuous system track, no tap rebuild |
| 7 | Manual microphone override | menu › Microphone › device | mic track from the chosen device | ✅ | 2026-10-12 | MacBook ↔ CMF Buds in manual: `deviceChange` "(manual)"; Automatic goes back to the Teams mic |
| 8 | Pause / resume | right-click twice (before 2026-10-12: left-click) | `pause`/`resume` markers; no audio during the pause | ✅ | 2026-10-12 | accidental on a real call (item `01a12f27…`): two `pause`/`resume` pairs at 62.5 s and 67.4 s, pauses excluded from the timeline; 2026-10-12 inverted clicks verified live (ADR-0026): left → menu, right → start/pause/resume |
| 9 | New recording | menu › New recording | two rows; the second starts where the first ends, with no gaps | ✅ | 2026-10-12 | two rows, the second starts at the instant of the first (08:41:01) |
| 10 | Sleep | close the lid during the recording | `autoPauseSleep` marker; on wake the "Resume" prompt | ✅ | 2026-10-12 | `autoPauseSleep` at 66 s; on wake "Recording paused" window (Resume / Stop and save / Keep paused); chose Stop and save → finalized |
| 11 | Crash | `pkill -9 -x IAGO` during the recording, then reopen | "Recovered an interrupted recording" notification; ≤ 2 s lost | ✅ | 2026-10-12 | kill -9 at ~25 s: 25.07 s recovered. Bug found and fixed: an empty system track (no app playing) wasn't created during recovery; now it is filled with silence |
| 12a | Mic permission denied | disable IAGO in Privacy & Security › Microphone, then start | "Microphone access denied" alert, no recording started | ✅ | 2026-10-12 | alert with "Open Settings" and "Cancel", recording not started; generic icon in the alert (AppIcon missing, phase 1) |
| 12b | Silent mic track | input volume at 0 with system audio active, record 40 s | after 30 s attention icon and warning in the menu; back to normal when the mic resumes | ✅ | 2026-10-12 | attention icon after ~30 s, no interruption of the recording; back to normal raising the input volume |
| 14 | Mark moment | during the recording: menu › Mark moment; with ⌥ › Mark moment with note… | bookmark icon for 1 s; `bookmark` markers in `session.json` 5 s before the click (ADR-0024), with `detail` = note | ✅ | 2026-10-12 | simple bookmark and bookmark with note saved (before ADR-0024: at the moment of the click) |
| 13 | 2-hour drift | `afplay beeps.wav` (120 min) from the speakers during a recording | `iago-spike drift` < 50 ms | | | |

## Automated results already verified (phase 0)

| Date | Test | Result |
|---|---|---|
| 2026-10-11 | Scripted 20 s recording with `say` + "New recording" at 10 s | two rows, tracks aligned to the ms, continuous speech across the split |
| 2026-10-11 | `kill -9` after ~8.5 s | 8.44 s recovered, session finalized at restart |
| 2026-10-11 | Drift over 3 min (beep every 10 s, built-in speakers) | constant offset ~47 ms (acoustic + device latency), drift 3.1 ms |
| 2026-10-11 | No audio playing | the tap delivers no buffers until some app plays: gap = silence, tracks of equal duration, no spurious rebuild (after fix) |
| 2026-10-11 | Scripted Mark moment at 3 s | `bookmark` marker at 3.17 s with note |

## Scripted launch (Debug build only)

```bash
open IAGO.app --args -IAGOAutoRecordSeconds 600            # records 10 min and quits
open IAGO.app --args -IAGOAutoRecordSeconds 20 -IAGOAutoSplitAt 10
```
