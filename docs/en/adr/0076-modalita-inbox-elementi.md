# ADR-0076 — Simple Track mode, Inbox and Items

- Status: accepted (1.2.0-beta)
- Date: 2026-10-29
- References: ADR-0074 (open work, Track and Manage), ADR-0075 (views); discussion with the user of 2026-10-29 on four versions of a proposal with sample windows

## Context
- In the 1.1.0-beta trial, Track and Manage differed by a few statuses and some fields: the complexity was almost the same.
- The all-projects Kanban left out projects in Track, and this turned out to be absurd.
- «Track» and «Manage» alone did not say that they were modes, nor which one was the simple one.
- «To do» was not recognizable as the place for the work waiting for the user.
- «List» did not say that the project's calls, emails and documents are there.
- «＋ Add» seemed to be only for writing key points.

## Decision
- **The mode decides how much is seen inside a project, never what exists.**
  - All key point kinds are there in both modes.
  - Inbox, Key points and the all-projects Kanban contain the work of every project, in any mode; each entry is shown in the mode of its project.
- **Names:** **Track mode** («simple and quick») and **Manage mode** («complete»).
  - Each has an icon (`book.closed`, `rectangle.split.3x1`) and a color (green and blue).
  - The pill next to the project name opens the two modes, explained.
  - The icon appears next to each project in the sidebar.
- **Track mode:**
  - views: Short overview, Items, Timeline and Graph; no Kanban and no «Show» menu;
  - the Graph has a switch in the pill, on by default;
  - a task is a checkbox, with who, by when, «waiting for» and checklist (always present, without switches);
  - open questions, risks and requests are written and closed with the outcome;
  - severity, «became an issue» and «derived from» are only in Manage; if already filled in they remain saved and an icon says so.
- **Manage mode:** everything, without limits. It remains the default mode.
- **Short overview** (in Track): one column with three blocks, «To do», «Keep an eye on» and «Latest decisions and milestones». An empty block does not appear.
- **Window on the first visit** to a project: it states the mode and what each one offers, and one click changes mode.
  - «OK» closes it and the window comes back the next time; «Don't show again» removes it for that project.
  - On a client it chooses the mode of its new projects and of those for which the user has not chosen one.
- **Inbox:** it takes the place of «To do». It is at the top of the sidebar, in bold, separated by a line, with a red badge counting the user's overdue or today's entries and the suggestions to confirm.
  - «Unfiled» becomes **«Unfiled items»**, right below, with the `questionmark.folder` icon.
- **View bar:** `[Overview] [Items] │ [Timeline · Kanban · Graph]`, all with an icon.
  - **Items** (formerly «List») shows only items.
  - «Show» applies to Timeline and Graph, with the entries Everything, Items and Key points.
  - **Map becomes Graph again.**
- **«＋ Add»** ends with «Import files and items…». It opens a window with:
  - an area to drag files onto and «Choose from the Mac…»;
  - From clipboard, From text (the field for writing opens) and Email without a file;
  - the destination, that is, the project and its streams.

  What is imported goes into that project, not into «Unfiled items».

## Consequences
- Of ADR-0074, it replaces:
  - the Track statuses (Open, Waiting, Done, Cancelled), which become the checkbox and the outcomes;
  - the exclusion of projects in Track from the all-projects Kanban.

  Of ADR-0075 it replaces the List with «Show», the mixed list and the name Map.
- No data migration.
- In the archive settings, so that they carry over with the backup: a client's mode for new projects (`work.clientMode.<id>`) and the projects with a mode chosen by hand (`work.modeChosen`).
- In `UserDefaults`, only display preferences of that Mac: the Graph switch per project (`work.graphHidden`) and the windows already closed for good (`work.modeIntro.dismissed`).
- Removed `Archive.trackedProjectIDs()`.
- The demo tour does not show the first-visit windows: it shows them itself. At the end of the run it quits with `exit(0)`, because `terminate` left the app open.

## Amendment of 2026-10-30 (1.2.4-beta)
- **Two badges instead of one.** A single number adding up due dates and suggestions could not be found in the Inbox: 38 suggestions sat in one row with a link to Key points.
  - **Red, with «!» (Do now):** what needs action, except the suggestions. The user's entries late or due today, those with no owner, the overdue waits (`OpenWork.needsAction`).
  - **Yellow, with the sparkle (Suggestions to confirm):** the pending key point suggestions.
- **The Inbox in three blocks**, each with its number in the header, in the same colour and with the same sign as the badge (`InboxBlockHeader`, `InboxCountBadge`):
  - **Do now:** late, today, no owner, overdue waits;
  - **Suggestions to confirm:** all of them, by source item, three per item and then «Show the other»; they are confirmed, edited and dismissed there, also all together («Dismiss these», «Dismiss all…»);
  - **Later**, with no badge: this week, after it, no date, waits not yet overdue, pinned checklists.
- Every unit of a badge is a row you can see in the Inbox. Key points keeps its «To confirm» block.
