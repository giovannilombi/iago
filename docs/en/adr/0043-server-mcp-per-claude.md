# ADR-0043 — MCP server for Claude

- Status: accepted
- Date: 2026-10-15
- Spec references: sec. 3.14 (FR-130…132), 12 (+ v1.4 update), 4.2; ADR-0010, ADR-0028, ADR-0038

## Context
Phase 3 starts with Claude's access to the archive (spec 12). According to the spec, the server reads "the DB read-only". The user asked that Claude also be able to read encrypted content, that is the full transcripts with the updated speaker names and the text of documents and emails, and not just the search index. The index already contains those texts unencrypted, but split by sentence and with the speaker names as they were at indexing time.

## Decision
- **`iago-mcp` executable** inside the bundle (`IAGO.app/Contents/MacOS/iago-mcp`):
  - signed like the app;
  - **stdio** transport (JSON-RPC 2.0, one message per line);
  - no network port. The automatic network check applies to it too.
- **Reading:**
  - **database:** read-only connection (`readonly`), without migrations. WAL allows reading while the app writes;
  - **encrypted files:** the server reads the master key from the Keychain, like the app (ADR-0028), and decrypts in memory only what the response needs. It never writes decrypted files to disk;
  - **first opening:** macOS asks once to allow `iago-mcp` access to IAGO's key. The answer is "Always Allow". If the user denies, the tools respond with a clear error and read nothing.
- **Only write: the access log.** Each call adds a row to `audit_log` with:
  - actor `mcp`;
  - the tool used;
  - the parameters, abbreviated;
  - the number of items returned and their IDs.
  The returned content is never logged. The write happens on a separate, short-lived connection, opened only for this.
- **Boundary:**
  - the server sees **only** projects with "Available to Claude" (`claude_accessible`, off by default);
  - items without a project, in the Trash, or deleted are never visible;
  - a decision or note is visible only if it belongs to an enabled project.
- **Tools** (spec 12 v1.4). They accept the project by ID or by name and, where needed, a stream by name:
  - `list_projects`;
  - `search`;
  - `get_item`;
  - `project_timeline`;
  - `list_decisions`;
  - `list_notes`;
  - `get_thread`;
  - `export_project`.
  The descriptions explain to Claude the item types, the user's notes, the decision statuses, and possible OCR errors.
- **Response format:** Markdown, in the same format as the LLM export (ADR-0041), so that Claude always cites title, date, and minute.
- **Settings › Claude:**
  - the switch for each project;
  - the configuration to copy for Claude Desktop and Claude Code;
  - the warning: *content read by Claude is sent to Anthropic's servers*;
  - the access log.

## Consequences
- Claude receives complete and up-to-date content, identical to the export.
- The master key is read by a second process signed by the same team. The risk is limited, because the server runs only when Claude starts it and sees only enabled projects.
- Network calls remain unchanged: sending to Anthropic is done by Claude Desktop, with the user's subscription, and IAGO declares it in the warning.
- The spec said "DB read-only": the deviation concerns only reading the key and inserting into the access log.

## Update 2026-10-15: connections per scope
- **One connection per scope.** The user can create several connections, choosing them from a list in Settings › Claude or in the Settings of a project or client:
  - **all accessible projects:** `iago`;
  - **a client:** `iago-<cliente>`, started with `--client ID`;
  - **a project:** `iago-<progetto>`, started with `--project ID`. With a single project, Claude does not need to specify it in the tools;
  - **all projects plus "Unfiled" items:** `iago-tutto`, started with `--unclassified`. The virtual project is called "Unfiled".
- **Deviation from FR-131.** The spec said rows without a project are never accessible. Now they become accessible, but only in a connection explicitly created by the user, with a warning in orange. The other connections continue to exclude them.
- **Boundary unchanged:** in every scope only projects with "Available to Claude" count, and the Trash stays excluded.
- **Removing a connection:** Settings › Claude lists those already present in Claude Desktop, with "Remove". Before every change IAGO saves a copy of the configuration file (`.bak-iago`).

## Update 2026-10-15: copy of the key for the connection
- **The problem.** When started by Claude Desktop, the server cannot show the Keychain access prompt and fails with error -25320 (`errSecInteractionNotAllowed`).
- **The user's choice (option A):**
  - at IAGO launch, and when a project becomes accessible, the app passes the master key to `iago-mcp --provision` through a pipe, never via a file or the command line;
  - the server saves it as its own Keychain entry (service `com.giovannilombi.iago.mcp`, account `master-key-copy`), which it can then read without prompts.
- **Reading the key:**
  - the server uses its own copy first, and only if it is missing the app's entry;
  - it never creates a new key.
- **Consequence:** the login Keychain holds two copies of the master key, both on this Mac and not synced. If no project is accessible, the copy is not created.
