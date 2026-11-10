# ADR-0099 — Deleting projects, clients and streams: Trash or permanent deletion

- Status: accepted
- Date: 2026-11-10
- Changes: ADR-0030 (Trash, now also for projects), ADR-0038 (deleting clients and streams: same rules, clearer confirmations)
- References: ADR-0039 (project keys), ADR-0044 (Claude); user request of 2026-11-10

## Context
- Clients and streams were deleted with a right-click in the sidebar; a project only from Settings › Projects, and only for good (warning, DELETE, last confirmation).
- Deleting a client moved its projects to «No client» without saying so; deleting a stream did not say how many items used it.
- A project deleted by mistake could not be recovered.

## Decision
- **Project, from the right-click menu (*Delete project…*) and from Settings, with the same dialog:**
  - it says what the project holds (items, transcripts, notes) and **lists the streams** that go with it;
  - it lets the user choose, explaining the difference:
    - **Move to Trash** (the default): one confirmation is enough, since it can be undone. The project disappears from the sidebar, project menus, search, Inbox, Key points, the graph and Claude, but stays on the Mac. It can be restored from the Trash for **30 days**, then it is deleted for good on its own. *Empty Trash* deletes it too;
    - **Delete permanently**: the earlier path, that is typing DELETE and then the last confirmation.
- **Client:** one confirmation that **lists its projects, with their streams**. Projects are never deleted with the client: they move to «No client» with everything in them. The user chose this simple rule over choosing, for each project, another client or deletion.
- **Stream:** one confirmation that says how many items, key points and notes lose the label. No Trash is needed, since no content is lost.
- **How it is built:**
  - **migration `v25-project-trash`:** one column, `project.trashed_at`, only added;
  - **the project's items** go to the Trash with it (`trash_reason` = `project`), so every query that leaves out trashed items leaves them out too. They are not listed one by one in the Trash. Those already in the Trash stay there with their own date;
  - **the project's notes, key points, checklists, streams and search rows** are left out with `Archive.outsideTrashedProjects`;
  - **Claude** only sees the projects of `projects()`, which leaves out those in the Trash;
  - **special cases:**
    - an item restored while its project is in the Trash comes back without a project, in «Unfiled items»;
    - a project restored after its client was deleted comes back in «No client».

## Consequences
- A project deleted by mistake can be recovered for 30 days, as it was.
- In the Trash a project takes space on the Mac until it is deleted.
- **Going back:** an earlier version ignores the new column and would show projects in the Trash as normal ones. No data is lost.
