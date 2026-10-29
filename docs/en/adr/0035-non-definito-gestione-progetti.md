# ADR-0035 — "Undefined" and project management

- Status: accepted (user request, 2026-10-12)
- Date: 2026-10-12
- Spec references: FR-21, FR-40, FR-70

## Context
"Unfiled" shows items without a project or category. An item with a category but no project did not appear in any project and risked getting lost. The user also wants to manage projects (rename, archive, delete).

## Decision
- **"Unfiled"** = all items **without a project**, with or without a category: an item leaves it only when it gets a project.
- **"Undefined"**: a fixed entry, always first among the Projects, not deletable, not renamable, not pinnable. It is not a database row but a view: items without a project but with a category (which also stay in "Unfiled"). In pickers, "No project" becomes "Undefined".
- **Settings › Projects**: rename (data stays linked by ID), archive/restore (archived projects disappear from the sidebar and pickers, and stay here with all their content), delete.
- **Deleting a project** in three steps: a warning with what will be lost (items, transcripts, notes); typing `DELETE`; a final warning. Then crypto-shredding of all the project's items and tombstones for the notes and the project. It does not go through the Trash.

## Consequences
- Deviation from FR-21 ("Unfiled" no longer depends on the category, only on the project).
- Deleting a project is permanent by explicit choice: it is the only case, besides "Delete permanently" on a single item, that skips the Trash.
