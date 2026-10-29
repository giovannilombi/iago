# ADR-0072 — Mark moment with screenshot and shortcuts in all apps

- Status: accepted
- Date: 2026-10-27
- References: ADR-0024 (bookmarks), ADR-0019 (OCR with Vision), ADR-0058 (data), ADR-0060 (no real data), ADR-0067 (MiniCPM), ADR-0071 (Claude); user's directions of 2026-10-27

## Context
- During calls people share slides, tables and charts that the transcript does not contain.
- IAGO did not capture the screen. A local vision model (MiniCPM-V) would take up more memory on Macs already at their limit, and support in MLX Swift must be verified.
- Continuous automatic captures would weigh heavily on privacy: screenshots contain faces and content of other people.
- "Mark moment" and stop could only be used from the icon menu.

## Decision
- **«Mark moment with screenshot»**, from the icon menu or with a shortcut, **only on the user's request** and during a recording (also when paused):
  - it captures with ScreenCaptureKit the screen under the pointer (or all of them, as chosen), without IAGO's windows;
  - the text is read with **Apple's OCR** on the Mac (no model to download, no GPU memory);
  - image and text go into the session folder and then, with the recording, into the encrypted archive as a `screenshot` asset of the item, with the second of the call and the text (migration `v19-screenshots`).
- **Where it appears:**
  - in the **transcript**, a «Screenshot» line at its minute with the text read;
  - in the detail pane, the **Screenshots** section with thumbnails; the image opens with its text and you can listen to the call from there; it can be deleted;
  - in **search**, as a transcript line at that minute;
  - in **summaries and suggestions**: the text goes into the lines the engine reads, at its minute («Screenshot: …»), so a point can quote a slide.
- **Claude:** always reads the screenshots' text (in `get_item`); the **images** with `get_screenshots` only if the user turns on «Also share screenshot images with Claude» (off by default), scaled down to 1,568 pixels on the long side. Claude reads slides and charts better than OCR.
- **"Screen Recording" permission** in Settings › Permissions (optional). macOS periodically asks to confirm it: the guide says so.
- **Shortcuts in all apps** (`RegisterEventHotKey`, no permissions): Mark moment ⌃⌥M, with screenshot ⌃⌥S, Start/Stop ⌃⌥R. They can be changed, reset or turned off in Settings › General; a combination already used by another app is flagged.
- **No local vision model for now:** it will be evaluated only if OCR is not enough, together with ADR-0067.

## Consequences
- Screenshots take up space (a few MB each) and are encrypted like recordings.
- No real data in the repository: tests use made-up images and texts.
- A screenshot contains everything that was on the screen, notifications included: this is why it is always a gesture by the user and images do not go to Claude without an explicit choice.
