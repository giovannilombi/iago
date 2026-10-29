# ADR-0075 — Project views: how to look and what to show

- Status: accepted (1.1.0-beta; updated by [ADR-0076](0076-modalita-inbox-elementi.md))
- Date: 2026-10-28
- References: ADR-0037 (timeline and log), ADR-0045 (graph), ADR-0074 (open work, Track and Manage); discussion with the user of 2026-10-28 on the alternatives for the view bar (style B2)

## Context
- With 1.1.0-beta the bar above the list had six equal buttons: List, Timeline, Key points, Graph, Overview, Kanban. It mixed forms (list, timeline), content (key points) and pages (overview), without a hierarchy.
- The Kanban in the center column was too narrow to be usable.

## Decision
- **A project contains only one thing, its history** (calls, emails, documents, notes, key points); views are ways of looking at it. At the top, two independent choices:
  - **how to look**, from the simplest form to the richest: **List**, **Timeline**, **Kanban**, **Map** (formerly the graph);
  - **what to show**, the «Show» menu on the right: **Everything**, **Materials** (calls, emails, documents, notes), **Key points**.
- **Overview** stands apart, as the first button separated by a line: it is the project's page, not a way of looking at it.
- The previous views become combinations: List with Materials is the previous list, List with Key points is the Key points view, Timeline with Everything is the timeline, Map with Everything is the graph. List with Everything is new: materials, key points and notes in a single list by date.
- The **Kanban** shows only open work («Show: Open work», fixed) and exists only in projects in Manage.
- **Kanban, Overview and Map are wide:** they take up the space of the list and the detail. What opens from them appears in a **panel on the right**, closed with ✕ or Esc. List and Timeline keep the detail on the right.
- **The Overview uses the width:** a band of numbers across the whole row; below, two columns of cards (on the left what to act on, on the right what changed, status report and checklists), a single column when the window is narrow.
- **IAGO remembers the last combination for each project, client, stream and library location.** The first time, a project, a client or a stream opens on the Overview.
- «Key points» and «To do» in the sidebar have only List and Kanban (the all-projects Kanban is wide too).

## Consequences
- `AppModel.ViewMode` becomes `overview, list, timeline, board, map`, with `ViewContent` (`all, materials, keyPoints`) for «Show»; the choice is saved in `UserDefaults` (`views.byScope`), not in the archive.
- The window has two layouts: three columns (sidebar, list, detail) and two columns (sidebar, wide view with the panel on the right).
- Guide, demo tour and tester checklist describe the new bar.
