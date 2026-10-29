# ADR-0038 — Client › Project › Stream hierarchy

- Status: accepted
- Date: 2026-10-13
- Spec references: sec. 8.4 (project), FR-70, FR-153; user request

## Context
Some clients have several active projects, and some projects have several lines of work. Spec v1.4 provides only flat projects. The user chose:
- a tree per client in the sidebar;
- no item attached directly to the client;
- streams in the sidebar too;
- multiple streams per item.

## Decision
- **Migration `v7-hierarchy`:**
  - table `client` (name, color, archived, sync columns);
  - column `project.client_id`, optional;
  - table `stream` (`project_id`, name, color, order, archived, sync columns);
  - link tables `item_stream` and `decision_stream`, many-to-many.
- **A client contains only projects.** Deleting it leaves the projects without a client.
- **Streams:**
  - A stream belongs to a project. An item or a decision can be in several streams of its own project; those of other projects are ignored.
  - If an item or a decision changes project, it loses the streams of the previous project. The UI asks for confirmation.
  - Deleting a stream only removes the label.
  - Deleting a project also deletes its streams.
  - A new decision taken from an item inherits the item's streams.
- **Scopes:**
  - `LibraryScope`, `DecisionQuery.Scope`, and `SearchScope` are extended with client and stream.
  - A client aggregates all its projects.
  - A stream filters the items and decisions that contain it.
  - Search within a stream also includes the notes of the stream's items.
- **Sidebar:**
  - at the top the pinned projects, flat, with the client's name in small type;
  - then the clients, expandable, with their projects, each with its own expandable streams;
  - finally "No client".
  - The expanded state of the branches is saved.
  - A project is moved into a client by dragging it (text with the `iago-project:` prefix, never confused with a file), from the context menu, or from Settings.
- **Colors:** clients and streams are assigned, in turn, a color from a fixed palette (`Archive.palette`).

## Consequences
- People (Block 5) will be defined on the client and apply to all its projects.
- Export (Block 6) and MCP (Phase 3) will accept a client, a project, or a stream as scope.
