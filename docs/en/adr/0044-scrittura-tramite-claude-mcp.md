# ADR-0044 — Writing via Claude (MCP)

- Status: accepted
- Date: 2026-10-15
- Spec references: sec. 12, 3.14; ADR-0043; user request 2026-10-15

## Context
With the MCP connection (ADR-0043) Claude reads the enabled projects. The user also wants to be able to use Claude to write into IAGO: add and edit notes and decisions, create documents, insert items. Transcripts, audio, and original files must stay unmodifiable. What comes in from Claude must be recognizable as **entered by the user via Claude (MCP)**, not as autonomous work by an artificial intelligence.

## Decision
- **Separate per-project permission: "Claude can also write".**
  - It is a new column, `project.claude_writable`, off by default (migration `v11-mcp-write`).
  - It applies only if the project is also accessible and falls within the connection's scope.
  - Items without a project cannot be written from Claude.
- **Write tools:**
  - `add_note`: project note or note on an item;
  - `update_note`;
  - `add_decision`: with description, date, source, "supersedes", people, and tags;
  - `update_decision`: text, description, status active/cancelled, chain name;
  - `create_document`: Markdown document;
  - `add_email`: manually entered email, with sender, recipients, date, and direction.
  No tool touches transcripts, audio, originals, or the extracted text of imported documents.
- **Provenance:**
  - notes have `input = mcp`, decisions `origin = mcp`, items `source = mcp`;
  - changes go into the `mcp_change` table;
  - the interface shows **"Added via Claude (MCP)"** or **"Edited via Claude (MCP)"**, with Claude's mark.
- **Undo:**
  - `mcp_change` keeps, for each write, the object type, the ID, and, for edits, the previous values (as JSON in the database, which already holds the texts of notes and decisions unencrypted, spec 9.3);
  - in Settings › Claude, "Changes via Claude (MCP)" lists the writes with **Undo**:
    - an undone creation is deleted: an item goes to the Trash, a deleted decision reactivates the one it had superseded;
    - an undone edit goes back to the previous values.
- **Process:**
  - the server always reads from the read-only connection (ADR-0043);
  - a write connection, without migrations, opens only at the first call of a write tool;
  - IAGO, if open, notices changes by another process by checking `PRAGMA data_version` every 2 seconds, and reloads.
- **Log:** every write goes into `audit_log` like reads: tool, abbreviated parameters, IDs. Never the content.

## Consequences
- Claude becomes a tool to enter and tidy up information in IAGO, always at the user's request, always recognizable and undoable.
- The MCP server writes to the database; the protection is the double per-project permission, accessible and writable.
- Documents created by Claude are `document` items with the Markdown as both original and text, encrypted like the others.
