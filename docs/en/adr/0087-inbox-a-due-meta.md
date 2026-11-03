# ADR-0087 — Inbox in two halves, suggestions on the right, columns per place

- Status: accepted
- Date: 2026-11-03
- References: ADR-0076 (Inbox in three blocks), ADR-0086 (style); proposals approved by the user on the prototypes of 2026-11-03 (V1, discreet indicator; V3, suggestions on the right)

## Context
- In the Inbox the blocks stood one under the other in a single scroll: with many entries in *Do now*, the *Suggestions to confirm* ended up at the bottom, out of sight.
- Suggestions were confirmed in the narrow middle column, three per item and then "Show the other": awkward.
- The middle column's width, once changed, applied to every place.

## Decision
- **Two boxes at half height:** *Do now* at the top, *Suggestions to confirm* at the bottom. Each has its own fixed header (sign, title, badge, red or yellow line from edge to edge) and scrolls on its own. A handle between them changes their share (from 20% to 80%), which is saved; a double click goes back to half and half.
- **Later** and, with *Show closed*, the closed entries sit at the bottom of the *Do now* box, under a grey title with no badge.
- **Scroll bar always visible** when there is more below, whatever the Mac's setting; thin and faint (no track, a little stronger under the pointer). It disappears when everything fits.
- **"N more"** at the bottom right of the box: discreet, three small faint dots that light up once every 10 seconds (they stay still with *Reduce motion*), plus the number of entries below the last visible one. It disappears at the end of the list.
- **Suggestions per item:** in the bottom box, one box per item with kind, title, date, project, which suggestions it has ("Activity 2 · Risk") and how many. A click highlights it and opens all its suggestions on the right, each with sentence, minute, *Confirm*, *Edit…* and *Dismiss*; at the top *Open item*, *Confirm all* and *Dismiss these*. With no suggestions left the item leaves the list.
- **Columns per place:** the first time, the middle and right columns are half and half. If the user moves the divider, the width is saved for that place only: Inbox, Unfiled items, Recent, Undefined, Key points, Import, Trash, Search; projects, clients, streams, categories and tags share one per view (Items, Timeline, Key points). Until a width is chosen in a place, the columns stay half and half also when the window changes size.
- **Empty box:** it shrinks to its header with one line ("No suggestions to confirm.", "Nothing late, due today or without an owner.") and the other takes all the room. If both are empty, "Nothing to do" stays.

## Consequences
- `InboxBox`, `InboxSplit`, `InboxMorePill` and `ThinScroller` (`WorkShared.swift`) can be reused for other boxed lists; `ProposalItemCard` and `ItemProposalsPane` in `InboxProposals.swift`.
- `ContentColumnWidth` (`ColumnWidths.swift`) reads and moves the window's divider (`NSSplitView`), measuring the middle column from the edge of the sidebar, which floats over it. The widths are in `columns.contentWidth`; the demo tour neither reads nor writes them.
- The full-window views (Overview, Kanban, Graph, Activity, Categories and tags) do not change: their right-hand panel stays as it is.
- The demo tour also takes the review shots `inbox-basso` (short window) and `inbox-proposte` (suggestions open on the right), which do not go into the guide.
