# ADR-0047 — Claude writes with context and preview

- Status: accepted
- Date: 2026-10-16
- Spec references: sec. 12; ADR-0043, ADR-0044, ADR-0046; user request 2026-10-16

## Context
With ADR-0044, Claude writes into IAGO exactly what it is asked, where it is asked. In the first real test:
- a decision added by Claude took the date of the email it came from, rounded to the minute, and ended up at the bottom of the previous day, below the attachments: the user did not see it;
- Claude cannot tell a note from a decision, does not look at existing decisions to suggest superseding them, and does not know about streams.

The user asks that Claude understand the context, ask when in doubt, and that everything it writes end up in the right place. The archive's consistency must be guaranteed by IAGO itself, not only by Claude's good will.

## Decision

### 1. Mandatory preview
- Every write tool works in two steps.
  1. **Without `confirmation`**, it writes nothing and returns a **preview**:
     - what will be written and of what type;
     - project and stream;
     - what it is linked to and which entry it supersedes;
     - date, and **where it will appear in the timeline** ("at the top", or "on Oct 15, next to «…»");
     - the **doubts** detected by IAGO (sec. 3);
     - a confirmation code.
  2. **With `confirmation` equal to that code and the same parameters**, it writes.
- The code is tied to the parameters: if Claude changes anything after the preview, a new preview is needed. It expires after 15 minutes.
- The instructions ask Claude to show the preview to the user and to confirm only after their OK.
  - The server cannot verify that the user has seen it: this remains up to Claude and the client's permissions.
  - The server does guarantee, however, that no write happens without a preview computed on the same parameters.

### 2. Dates
- **Default: now.** An entry added by Claude appears at the top of the timeline.
- A different date only if the user specifies it. Claude passes it in `date`, or with `date: "source"` takes the **exact date of the source**: the item's time, plus `at_sec` for a call.
- If the date is in the past, the preview flags it with the position in the timeline, so Claude has it confirmed.

### 3. IAGO's checks
The preview flags as doubts:
- **similar active decisions** in the same project (or stream), when `supersedes_id` is not given, so that Claude asks whether they should be superseded. Similarity by words in common, without models;
- a date **earlier** than the entry being superseded;
- a `supersedes_id` that **already comes later** in the chain. The same case handled in the app: with confirmation, the chain order is changed;
- a stream that does not exist in the project. This is an error, not a doubt: Claude receives the list of valid streams.

### 4. Streams and links
- `add_note`, `add_decision`, and `create_document` accept `stream`: the name of a stream of the project.
- Notes currently have no streams.
  - New table `note_stream` (migration `v12-note-stream`).
  - A note in a stream appears in that stream's timeline.
  - The note window also lets the stream be chosen by hand.
- `add_note` with `item_id` links to any item: call, email, document, file.
- `add_decision` accepts `source_item_id`, any item, and `source_note_id`, the note it comes from.
- `create_document` accepts `related_item_ids`: `item_link` links with origin `mcp`.
- `update_decision` accepts `supersedes_id`, with the same checks as the preview.

### 5. Finding decisions
- `list_decisions` accepts `query`: words from the text or the description.
- It serves for "the decision on the contribution has changed": Claude finds the candidates and, if there is more than one or none, asks.

### 6. Working instructions
The instructions IAGO sends to the connection become a working manual:
- **read before writing:** active decisions, streams, notes, and recent timeline of the project;
- **choose the type:**
  - note: a piece of information to remember;
  - decision: something decided that holds until superseded;
  - task: something to do;
  - milestone: a fact that happened;
- **ask instead of guessing:** type, stream, decision to supersede, date, link;
- **follow the flow preview, user's OK, confirmation**, and report where the entry ended up.

### 7. Tool annotations
The tools have the standard MCP annotations and an Italian title:
- **read:** `readOnlyHint: true`;
- **write:** `readOnlyHint: false`, `destructiveHint: false` (everything can be undone from IAGO), `idempotentHint: false`;
- **all:** `openWorldHint: false`.

### 8. Permissions in the clients
Permissions are granted by the client: IAGO cannot grant them to itself. In Settings › Claude:
- **Claude Code:** an "Allow all tools in Claude Code" button. It adds `mcp__<connessione>` to `permissions.allow` in `~/.claude/settings.json`, after a confirmation and only in that entry of the file;
- **Claude Desktop:** an "Avoid permission prompts" box with the steps in the connector settings. It warns that after a Claude Desktop update they may need to be repeated, and that in business accounts it depends on the administrator.

## Consequences
- Every write costs one more step, the preview, but nothing enters IAGO without date, position, links, and chain having been shown.
- Claude's entries are, by default, the most recent in the timeline.
- Migration `v12-note-stream` brings streams to notes too, in the app as well as in Claude.
- It replaces, for write tools, the one-step flow of ADR-0044. Provenance, undo, and per-project permissions remain as in ADR-0044.
