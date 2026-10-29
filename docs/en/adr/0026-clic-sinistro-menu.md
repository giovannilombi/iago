# ADR-0026 — Left click opens the menu, right click starts and pauses

- Status: accepted (user request, 2026-10-12)
- Date: 2026-10-12
- Spec references: FR-02, FR-03

## Context
FR-02 assigns start/pause/resume to the left click and FR-03 the menu to the right click. In phase 0 testing the user unintentionally paused the recording five times by clicking the icon to open the menu or to stop: the left click is the instinctive gesture to "see" or "stop", and an unintended pause during a call loses audio without the user noticing.

## Decision
- **Left click** → menu (status, duration, microphone, Pause/Resume, Stop, New recording, Mark moment, …). When idle, the menu offers "Start recording".
- **Right click or Control-click** → start / pause / resume.

## Consequences
- Deviation from FR-02 and FR-03 (behaviors swapped).
- Starting a recording requires a right click or two left clicks (menu › Start recording).
- The planned global shortcuts (FR-05 and following) do not change.
