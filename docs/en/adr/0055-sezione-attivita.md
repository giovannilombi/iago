# ADR-0055 — "Activity" section

- Status: accepted
- Date: 2026-10-21
- Spec references: sec. 12 (jobs), 16 (UI); user request 2026-10-21

## Context
IAGO's jobs show their state in different places:
- recording and transcription in the menu bar;
- transcription also in the item's detail pane;
- downloads and indexing in Settings;
- suggestions in the detail pane.

The user wants a single place, under Import, with everything in progress and the percentage.

## Decision
- **"Activity" entry in the sidebar**, under Import, with a badge counting the jobs in progress or queued. The badge disappears when there is nothing.
- **The view has three groups:**
  - **In progress**, each with a bar, percentage and, when it can be estimated, the time remaining:
    - recording: duration, microphone, echo cancellation, mute, with "Open", "Pause" and "Stop";
    - transcription;
    - key points and suggestions, text cleanup and summary (ADR-0054). For engine jobs the percentage comes from the completed chunks;
    - indexing for meaning-based search;
    - model downloads (transcription, engine, search);
    - imports from watched folders and from Claude, backups, exports.
  - **Queued**: the order of the jobs, with "Cancel" and "Do this first".
  - **Recently finished** (last 24 hours) and **failed**, with "Open item" and "Retry".
- **Where it reads from:** the view reads the same states already used by the menu bar and Settings (job queue, recorder, engine, downloads). There is no new log: the recently finished ones come from the `job` table and from the session's jobs.
- **Content:** only item titles and job types, never transcript text.

## Consequences
- A single place to understand what IAGO is doing and why the fan is spinning.
- Every new kind of job must appear here. It is a rule like the one for Permissions.
