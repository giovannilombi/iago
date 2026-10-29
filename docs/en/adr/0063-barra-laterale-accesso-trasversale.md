# ADR-0063 — Sidebar and cross-project access to categories and tags

- Status: accepted
- Date: 2026-10-21
- References: ADR-0035, ADR-0038 (hierarchy), ADR-0054; user requests 2026-10-21

## Context
The sidebar mixed projects, categories and tags, and with many projects it became unmanageable. Categories and tags are needed, though, for summaries and for cataloging, and must also be reachable across projects.

## Decision
- **Three parts, separated by thin lines:**
  - at the top, fixed: Unfiled, Recent, Key points, Import, Activity, Categories and tags;
  - **PROJECTS**, the only part that scrolls, which contains:
    - *Pinned* (red pin), with pinned projects, categories and tags;
    - **clients as an accordion**, as in Teams: click to open or close, ⌥-click to open only that one, "→" and "+" on hover;
    - *No client* (small gray square), always last, with *Undefined* at the bottom;
  - at the bottom, a fixed bar with "＋" (new project or client) and the trash with its count.
- **Filter projects** appears above 15 projects.
- **Categories and tags**, a view with counts. A click opens the list across all projects; a right-click pins it in *Pinned*.
- **In search** `#` and `categoria:` suggest tags and categories; **in the detail pane** a click on a tag or on the category opens the cross-project list.

## Consequences
- The Categories and Tags sections are no longer in the sidebar.
- The fixed part at the top is measured on the last row, so it follows the icon size chosen in System Settings.
