# ADR-0004 — Mic track = microphone in use by the call app

- Status: accepted
- Date: 2026-10-11
- Spec references: sec. 3.2 (FR-12), 6.2, 17.4

## Context
The system default input does not necessarily match the microphone chosen in the call app (e.g., Teams on AirPods while the default is the built-in microphone). Recording the wrong microphone means losing the user's voice.

## Decision
IAGO identifies the input device actually used by other processes through Core Audio process objects (process list, "is running input", "devices" per process), excluding itself and giving priority to known call apps (Teams, Zoom, Meet in browsers, Slack, FaceTime, Webex). Fallback: system default input. Manual override from the menu. The choice is continuously re-evaluated (Core Audio listener + polling every 2 s); on a change, recording continues on the same track with aligned silence and a `deviceChange` marker.

## Consequences
- To be validated in phase 0 for native Teams, Zoom, Meet in Chrome and Safari. If a case does not work: a new ADR with a fallback.
- The selection logic is a pure function, testable with fake process tables.
