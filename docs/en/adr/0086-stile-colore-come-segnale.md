# ADR-0086 — Style: colour as a signal, light and dark

- Status: accepted (1.2.13-beta)
- Date: 2026-11-02
- References: ADR-0084 (item detail), ADR-0085 (Overview of boxes); proposals approved by the user on the prototypes of 2026-11-02

## Context
- Every key point kind had its colour everywhere: box titles, tile labels, row icons, card background and border, the project label. Six or seven colours on the same screen, a "harlequin" effect.
- The sheet of a new key point showed all six kinds again as coloured pills, even though the user had just chosen one from the menu.
- In light the pages were almost all white, and a box's title blended with its first row.
- Light or dark could not be chosen inside IAGO.

## Decision
- **Colour as a signal (style A):**
  - neutral text, titles and labels included;
  - the kind's colour stays in the box's left bar and icon, in the dot of tiles and menus, and in the icon on the timeline rail;
  - rows, Kanban and timeline cards have a neutral background and grey icons; **red** only for what asks for attention (overdue, blocked, high risk); **blue** for what can be clicked and for the selection;
  - sidebar with grey icons; the Inbox badges, the clients' squares and the mode icon keep their colour.
- **Box titles (T2):** a thread from edge to edge separates title and content, a little lighter than the box in dark and a little darker in light, never coloured. The Inbox keeps its red and yellow lines.
- **"Add" sheet:** the title is "Add", like the button pressed (or "Edit"), followed by the kind in a tile; a click on the tile opens the six kinds with a line of explanation. The "Add" menu has the kind's dot and separates decisions and milestones from open work.
- **Transcript (M2):** bookmarks and screenshots on a faint veil of their colour with a thread on the left; normal text, a thumbnail for screenshots.
- **Kanban (K3):** columns in boxes, a little darker than the window, with the status colour's line under the title; cards with a marked border.
- **Activity (A2):** one centred column, with *Last 7 days* and *Ready to work* side by side at the top. **Categories and tags** across the window.
- **Appearance:** a menu next to Settings, with *Automatic* (like the Mac, the default), *Light* and *Dark*.
- **Light without full white (cool grey):** pages #EDEFF2, boxes #F8F9FB, top bars #E6E9ED, a tinted sidebar darker than the pages. In dark the system's colours stay.

## Consequences
- Colours are defined in one place (`IAGOColor`, `AppAppearance.swift`) and adapt to the appearance on their own.
- The guide's screenshots are retaken when the look is settled, with `scripts/guide-screenshots.sh`.
- Text fields and the less used sheets stay the system's.
