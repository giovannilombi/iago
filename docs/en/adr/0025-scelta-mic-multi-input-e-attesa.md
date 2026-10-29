# ADR-0025 — Microphone choice: multiple inputs per app and a wait before falling back

- Status: accepted (phase 0 testing with the user, 2026-10-12)
- Date: 2026-10-12
- Spec references: sec. 6.2; ADR-0004; `docs/testing/capture-checklist.md` rows 3–5

## Context
ADR-0004 makes IAGO follow the microphone used by the call app, falling back to the Mac's default input when no app is using the microphone. Tests with real calls (Teams, Zoom app and browser, Meet in Safari and Chrome) showed two uncovered cases:

1. **Multiple inputs for the same process.** With Meet in Chrome set to "default", when headphones are connected Chrome opens the new default input but also keeps the previous one open. Core Audio lists both (`Microfono MacBook Pro, CMF Buds Pro 2`); IAGO took the first and recorded for about a minute from the wrong microphone (verified with `kAudioDevicePropertyDeviceIsRunningSomewhere`: the headphones were used only by Chrome).
2. **Momentary settling.** When connecting or disconnecting devices, Safari and Teams appear without a microphone for 1–5 s. IAGO immediately fell back to the default input and then switched back: with Meet in Safari, two round trips in 4 s.

Muting in the call app does not release the microphone in any of the apps tried: no special behavior is needed for mute.

## Decision
- **Multiple inputs:** if the call app's process lists several available inputs, the choice is, in order: the Mac's default input if it is among them; otherwise the microphone IAGO is already using; otherwise the first one.
- **Wait before falling back:** when the followed app (call or other app) stops using the microphone and the resolver would propose the default input, IAGO stays on the current microphone for **3 s** (`MicFallbackHold.interval`), **only if that microphone is still connected**. If the microphone was disconnected, or if the app switches to another microphone, the change is immediate. With the periodic check every 2 s, the fallback happens within ~5 s.
- The wait does not apply to manual selection, nor when the current microphone is already the default input.

## Consequences
- Fewer spurious microphone changes in the `deviceChange` markers, no recording from the wrong microphone in the Chrome case.
- If the call app really switches to the default input after an interruption, IAGO follows it with up to ~5 s of delay, recording in the meantime from the previous microphone (still connected, so the voice is present anyway).
- Pure, tested logic (`MicDeviceResolver.preferredDevice`, `MicFallbackHold`).
