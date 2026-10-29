# ADR-0024 — "Mark moment" points to 5 seconds before the click

- Status: accepted (user request during phase 0 testing)
- Date: 2026-10-12
- Spec references: FR-05; ADR-0018

## Context
FR-05 creates the bookmark "at the current timestamp". In real use, the interesting moment has already passed when the user reacts: they recognize it, open the menu, possibly hold ⌥ for the note. A bookmark at the moment of the click therefore lands a few seconds after what they wanted to mark.

## Decision
- The bookmark (with or without a note) is placed **5 seconds before the click**, measured on the recording's timeline (pauses are excluded).
- The reference is the instant "Mark moment" or "Mark moment with note…" is chosen; the time spent writing the note does not move the bookmark.
- If less than 5 seconds have passed since the start of the recording, the bookmark goes to 0: it does not cross the boundary with the previous recording ("New recording").
- The value is a constant (`RecordingSession.bookmarkLookback`); it may become a setting.

## Consequences
- Deviation from FR-05 ("current timestamp").
- Bookmarks imported in phase 1 into the `marker` table already have the anticipated time: the import must not correct them.
- In playback/transcript, the bookmark precedes by a few seconds the sentence spoken at the click: this is the intended behavior.
