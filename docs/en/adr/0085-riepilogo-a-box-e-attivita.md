# ADR-0085 — Overview of boxes, Track split in two, Activity across the window

- Status: accepted (1.2.12-beta)
- Date: 2026-11-02
- References: ADR-0055 (Activity), ADR-0075 (project views), ADR-0076 (Track and Manage), ADR-0084 (item detail: tiles and empty sections); proposals approved by the user on the prototype of 2026-11-02

## Context
- The Overview in *Manage mode* had six boxes of numbers at the top, with texts cut off and no wrapping when the window is not full screen. Below were two fixed columns with blocks of very different heights, which left empty spaces.
- In Manage the latest decisions and milestones were missing, while Track has them.
- In *Track mode* the Short overview was a single column in the middle of the window, which only improved after opening an entry.
- Activity showed «No item selected» on the right, but there is nothing to select there.

## Decision
- **Manage, a page of boxes.**
  - The boxes, in order of importance: *To do and due dates*, *Keep an eye on* (risks by severity and open questions), *Waiting on others*, *Latest decisions and milestones*, *Upcoming milestones*, *Status report*, *What changed*, *Checklist*, *Blocked*.
  - They sit in two "masonry" columns: each goes in the shorter column, measured with its real content. Below 860 points, also with the panel on the right open, they become one column.
  - At the top, always in view, the **boxes' tiles**, as in the item detail: one value per box. A click takes you to the box and makes it glow for half a second, even when it is already in view.
  - An empty box is reduced to its dashed header, with its sentence.
  - Counts by kind and progress bars leave the page: they stay in the rows, in the Kanban and in the Inbox.
- **Track, a page already split.** The Short overview keeps the panel on the right always open. With no entry open it shows the logo and «No item selected», without ✕.
- **Activity across the window.**
  - No detail column: *Open* shows the item in the panel on the right.
  - At the top the tiles: In progress, Queued, Last 24 hours, Failed. The sections are in the style of the item card, reduced to their header when empty.
  - On the right, or below with a narrow window, *Last 7 days* (calls, emails and documents per day, plus the transcriptions done) and *Ready to work* (Mac engine, space of the archive and of the models).
- **Sidebar:** a project's mode icon always has its colour, green for Track and blue for Manage. A click opens the mode choice, like the pill next to the name.

## Consequences
- The Manage page no longer has fixed positions: the order of the boxes stays, the column depends on the heights.
- The guide's screenshots of the Overview, the Short overview and Activity must be redone whenever these boxes change.
