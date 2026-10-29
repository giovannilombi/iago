# ADR-0045 — Graph view

- Status: accepted
- Date: 2026-10-15
- Spec references: sec. 3.17 (FR-160…165), 10.5; ADR-0015

## Context
The spec calls for a native view of the relationships between projects, items, people, organizations, topics, tags, and decisions. Notes are optional nodes. The view must start centered on the selected item, expand nodes on double-click, filter by type, have a time slider, and stay smooth up to 500 nodes. The spec asks to evaluate the Grape library or a home-grown layout with `Canvas`.

## Decision
- **No new tables and no new dependencies.**
  - The `GraphNode`, `GraphEdge`, and `Graph` models live in `IAGOCore`.
  - The `GraphBuilder` projection lives in `IAGOIntelligence`. It reads the existing tables in a single database read.
  - The force-directed layout is our own and drawing uses SwiftUI `Canvas`. For 500 nodes an O(n²) repulsion computation on a background thread is enough, so Grape is not needed: no dependency to verify and maintain.
- **Nodes:**
  - project, client (acting as "organization"), call, email, document, person, tag, and decision;
  - note, hidden by default;
  - "topics" will arrive with the local engine's extraction.
- **People:**
  - registered people, that is entities and contacts;
  - speakers with a name, excluding Me, Speaker N, and Room;
  - email senders and recipients, recognized by the contact with the same email, otherwise by address;
  - the user's addresses are excluded, otherwise they would become the center of everything.
- **Edges:**
  - item → project, project → client;
  - item ↔ tag and item ↔ person;
  - links between items;
  - decision → project, → source, → people, → tags;
  - decision → decision it supersedes;
  - note → item or project.
- **Different shapes and colors per type** (FR-162):

  | Type | Shape | Color |
  |---|---|---|
  | Project | rounded square | blue |
  | Client | square | client's color |
  | Call | circle | purple |
  | Email | diamond | indigo |
  | Document | rectangle | teal |
  | Person | hollow circle | orange |
  | Tag | hexagon | gray |
  | Decision | star | green |
  | Note | small square | yellow |
- **Modes:**
  - **Centered** (default, when an item is selected): the item and its neighbors at depth 1; double-clicking a node adds its neighbors;
  - **Whole scope**: project, client, or stream from the sidebar.
  - **Over 500 nodes:** notes are removed first, then the oldest items are grouped by month into an "N items · month" node.
- **Time slider** (FR-163): shows the graph as it was up to a date. Later items, decisions, and notes disappear.
- **Click on a node:**
  - item, decision, or note: it opens in the right panel, as in the other views;
  - person, tag, project, or client: a short card in the graph, with "Open" leading to the corresponding view.
- **Navigation:** drag to move the view or a single node, zoom with pinch or scroll wheel.

## Consequences
- The graph is always consistent with the archive, because it is recomputed on every change.
- The layout quality is sufficient for this use, but not that of a specialized library. If needed, Grape can be reevaluated without changing the projection.
