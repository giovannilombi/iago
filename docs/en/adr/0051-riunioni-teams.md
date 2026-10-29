# ADR-0051 — Detecting Teams meetings, suggesting recording, and following mute

- Status: accepted
- Date: 2026-10-19
- Spec references: sec. 6 (capture), 4.2 (network); ADR-0004 (the microphone "the others hear"); user requests 2026-10-16 and 2026-10-19

## Context
Users forget to record calls. The user wants IAGO to:
- notice a Teams meeting and suggest recording it, with the **meeting title** as a provisional title;
- when the user is **muted** in Teams, not record their microphone. Teams in fact keeps the microphone open even when muted, as seen in the October 12 test.

IT cannot be involved. What emerged from checks on the user's Mac:
- reading other apps' notifications is not possible: macOS does not allow it;
- the Teams and Outlook data folders are protected by macOS ("Operation not permitted"). The Outlook cache would require Full Disk Access and is fragile, so it is ruled out;
- Teams has a **local API for third-party apps**: a WebSocket on `ws://127.0.0.1:8124`, which the user can enable in Teams › Settings › Privacy. It reports in-meeting and mute. It is documented only by community projects (svrooij/teams-monitor, AntoineGS/teams-status-rs, ferenyl/Teams.ThirdPartyAppApi), not by Microsoft, and some companies' IT can disable it.

## Decision
### 1. Several sources, together
| Source | What it provides | Permission |
|---|---|---|
| **Teams local API** | in meeting, mute | enable it in Teams, then an "Allow" in Teams the first time (pairing) |
| **Call app using the microphone** (Core Audio, already used to choose the microphone, ADR-0004) | start and end of a Teams, Zoom, Webex, FaceTime, Slack call | none extra |
| **Mac Calendar** (EventKit) | meeting title and time, if the work calendar is synced there | Calendar access, requested only if the user enables it |

- **A call is in progress** if the Teams API says "in meeting" or if a call app has been using the microphone for at least 5 seconds. The delay avoids false alarms from audio tests.
- **The provisional title** is that of the Calendar event in progress: if there is more than one, the one with a Teams link is preferred. Otherwise, "Call Teams del 19 ott, 14:30", or with the app's name.
- **At the start time of a Calendar event** with a Teams, Zoom, or Meet link, a notification asks "«…» is about to start: start recording?", even before joining.

### 2. Suggestion or automatic recording
- When a call starts and IAGO is not recording, a notification asks **"You're in a Teams call: start recording?"**, with **Record** and **Not now**.
  - Without notification permissions, the suggestion appears in the menu bar menu.
  - "Not now" applies to that call.
- **"When a call starts" setting** (Settings › Audio): *Ask* (default), *Record automatically*, *Do nothing*. With "Record automatically", a notification warns that recording has started, with **Stop**.
- **At the end of the call:** if IAGO started recording from a detected call and the call ends, that is no longer in a meeting and the microphone free for 30 seconds, a notification suggests **"The call has ended: stop recording?"**. It never stops on its own.
- The provisional title becomes the item's title (`SessionManifest.suggestedTitle`), editable as always.

### 3. Mute
- With the Teams API connected, while the user is muted **the microphone track receives silence** and is not stopped, so the tracks stay aligned. The session timeline marks `micMuted` and `micUnmuted`.
- Without the API, mute is not known and the microphone stays recorded as today. Settings says so.

### 4. Network
- The connection to `127.0.0.1:8124` is **local only**: it does not leave the Mac and is the only new exception. There is a single piece of code that opens it (`TeamsLocalAPI.swift`), allowed by `check-network-apis.sh`. `CLAUDE.md` › Network and privacy, point 2, becomes "localhost to the Teams local API".
- The pairing token is in the Keychain.
- Only the connection and the pairing go into the access log, not the individual states.

## Consequences
- Without IT, and with only the API enabled in Teams, IAGO suggests recording and follows mute. Without the API, the microphone in use and the Calendar cover the start of calls and the title, but not mute.
- If Microsoft changes or removes the API, the rest remains. The API code is isolated, and connection errors are only a warning in Settings.
- The Outlook cache is not used.

## Change of 2026-10-20
- On the user's Mac the Teams local API is not available: the option does not appear in Teams, almost certainly blocked by IT. For **mute**, a second source is added, **macOS Accessibility** (`TeamsAccessibility.swift`):
  - IAGO looks for the microphone button in the Teams window and reads its text ("Riattiva microfono" means muted);
  - it is turned on and off in Settings › Audio › Meetings, with the Accessibility permission;
  - the **button texts are editable by the user** (advanced), so a change in Teams does not require a new version;
  - IAGO reads only the button's text, nothing else in the window.
- The local API remains, for Macs where it is active. If both are present, the API wins.
- **The "The call has ended: stop?" suggestion** appears for any recording in progress when the detected call ends, not only for those started from the suggestion.
- **Suggestions** are IAGO panels and not system notifications:
  - Record and Ignore always visible;
  - they stay at most 5 minutes, or 30 seconds if the user chooses so;
  - with overlapping meetings there is one per meeting;
  - in Settings there is "Show an example".

## Change of 2026-10-20 (2): which meeting it is
The user opened a second call while "TEAM LEAD" was still in progress in the Calendar, and IAGO suggested the wrong title: it picked the meeting that started first. Now `MeetingMatcher` decides:
- **certain**, and therefore no question, when:
  - the title of a Teams window contains the meeting's name: with Accessibility on, IAGO also reads the titles of Teams windows, only to compare them with the Calendar;
  - or a single meeting started around the time of the call (from 10 minutes before to 15 minutes after the start). Meetings with a call link take precedence.
- **not certain**: several meetings started together, or only meetings that started a while ago, because the call might be another one, not in the calendar. In these cases the panel asks which meeting it is, with one button for each and "Call Teams del …" as the last choice:
  - before recording: "Start recording? Choose the meeting:", and each button starts recording with that title;
  - if already recording: "Which meeting are you recording?". Until the user chooses, the best guess remains.
- The title is recomputed when recording starts, because the call might have changed. If the user chose from a panel, their choice wins.
