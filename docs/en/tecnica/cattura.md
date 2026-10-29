# Capture and meetings

## Two tracks
IAGO records **two separate tracks** (ADR-0002): the Mac's audio (the others) and the microphone (you). This way it always knows who the user is ("Me"), transcribes better and can discard echo.

| Track | How | ADR |
|---|---|---|
| System | Core Audio *process tap* (macOS 14.2+) on all output audio, with a private aggregate device | 0003 |
| Microphone | HAL IOProc on the input device, read as is, without touching the one used by the call app | 0004 |

- Every buffer carries the **host time** of the system clock: the tracks stay aligned even across pauses and microphone changes. Target: drift under 50 ms over 2 hours.
- **Automatic microphone:** IAGO uses the same microphone as the call app, follows it if it changes (headphones plugged in or removed), and with several inputs prefers the Mac's default one; it waits a few seconds before falling back to the default (ADR-0025).
- **No voice processing:** macOS echo cancellation (VPIO) was tried and withdrawn, because it took the microphone away from Teams during recording (ADR-0053). Echo cleanup after recording was also rejected (ADR-0064). Echo is handled during transcription.

## Writing and recovery
- **Incremental** writing to `tmp/sessions/<id>/`, with a *flush* at most every 2 seconds and a `session.json` with markers (pause, device change, bookmarks).
- When recording ends, the tracks are finalized as AAC and encrypted into the archive.
- **Recovery at launch:** a session that was not finalized (crash, shutdown) is recovered; an empty track is filled with silence to stay aligned.
- **Mac sleep:** automatic pause and a choice on wake.
- **Silent track:** after 30 seconds of silence on a track, IAGO warns.

## Recording interface
- Click on the icon: menu; right-click or Control-click: start, pause and resume. This way a careless click never pauses a call (ADR-0026).
- **Mark moment** places the bookmark 5 seconds before the click (ADR-0024).
- **Discard** keeps the recording recoverable for one hour (ADR-0032).
- **Mark moment with screenshot** (ADR-0072): `ScreenshotService` captures with ScreenCaptureKit (`SCScreenshotManager`) the screen under the pointer, or all of them, excluding IAGO's windows; the text is read with Vision OCR (`ContentExtractor.extract(image:)`). PNG and text go into the session folder with a `screenshot` marker in `session.json`; `RecordingArchiver` encrypts them as `screenshot` assets of the item, with `at_sec` and `text` (migration `v19-screenshots`). The text enters the search index as a transcript line and the lines read by the engine and by Claude (`SuggestionEngine.Input.load`).
- **Global shortcuts** (`GlobalShortcuts`): Carbon `RegisterEventHotKey`, no permissions needed; ⌃⌥M, ⌃⌥S, ⌃⌥R by default, saved in the archive (`shortcut.<azione>`), editable or can be turned off. Every combination contains ⌃ or ⌥ (never ⌘ alone) and cannot repeat the one of another IAGO action.
- The minute of a screenshot is that of the request (`HostClock` at the key press), not the end of capture and OCR; with several screens all are captured immediately and read afterwards, off the main thread. An import interrupted by a crash does not duplicate screenshots, and a deleted screenshot (or item) does not leave its text in the database.

## Meetings
Local-only detection (ADR-0051):
- **Apps using the microphone** (Teams, Zoom, Webex, FaceTime, Slack…), read from Core Audio process objects.
- **Mac Calendar** with EventKit, for the title and the suggestion at start time; with several overlapping meetings `MeetingMatcher` picks the best candidate and, if uncertain, asks the user.
- **Teams window titles** via Accessibility, to recognize the right meeting.
- **Teams mute** via Accessibility (the microphone button) or via the **Teams local API** on `127.0.0.1:8124`, only if the user enables it: while muted, the microphone track receives a marker.
- The suggestion to record appears in an `NSPanel` with the choices (record, ignore, right meeting).
