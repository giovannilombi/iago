# Claude and MCP

IAGO can be connected to **Claude Desktop** or **Claude Code** with the Model Context Protocol, to reason about projects with a more powerful model. It is optional and decided project by project.

## The server (ADR-0010, ADR-0043)
- `iago-mcp` executable in the app bundle (`Contents/MacOS`), package `IAGOMCP`.
- **stdio only:** Claude launches it as a process; no network port is opened.
- It reads the same archive as the app; a key for the server is prepared by the app at launch.
- **Visibility per project:** a "Available to Claude" flag (off by default) and, separately, "Claude can write". Items without a project are never visible.
- Every call ends up in the **access log**.

## Tools
| Read | Write (with preview) |
|---|---|
| `list_projects`, `recent_items`, `project_timeline`, `search`, `get_item`, `get_thread`, `list_decisions`, `list_notes`, `summary_template`, `get_screenshots`, `find_file`, `export_project` | `add_note`, `update_note`, `add_decision`, `update_decision`, `add_email`, `create_document`, `import_file`, `write_batch`, `set_summary`, `propose_suggestions` |

**Open work (ADR-0074).**
- `list_decisions` filters by the six kinds (or `work`), by the new statuses (or `open`) and by `owner`, and shows `decision_id`, owner, due date, waits, priority, dependencies, checklist and outcome.
- `add_decision` and `update_decision` accept `kind`, `status`, `owner`, `waiting_on`, `due`, `waiting_until`, `starts_at`, `happened_at`, `priority`, `estimate`, `severity`, `recurrence`, `derived_from_id`, `blocked_by_ids`, `checklist`, and when editing `outcome_kind` and `outcome`.
- New people are created only on confirmation; the preview flags similar names ("Did you mean …?").
- Undo also restores these fields, the dependencies and the checklist.

## Summaries and suggestions made by Claude (ADR-0071)
- **Finding the item:** "Copy for Claude" in the item card copies the `item_id` and the request; without it, `recent_items` lists the latest items of all readable projects.
- **`set_summary`:** Claude sends sections and points with the **exact quote**; IAGO composes them with `SummaryGenerator.compose`, in the category's template (`summary_template`), verifying every quote with `KeyPointExtractor.locate` as for the local engine. Points without a quote, with a quote that is not found, or in a section the template does not have, are discarded and reported in the preview. Points read from a screenshot use `screenshot_at` and are kept only if the call has a screenshot within 5 seconds of that minute.
- **`propose_suggestions`:** decisions, tasks, open questions, risks and requests (with a verified quote, and `owner`, `due`, `waiting_on`, `severity`, `closes`) and tags become `suggestion` with `origin = claude`, awaiting confirmation. The engine and Claude do not delete each other's pending suggestions.
- The summary is saved with `origin = claude` and `model` = the app Claude is used from (`clientInfo` from `initialize`). "Regenerate" with the engine asks for confirmation; automatic summarization skips items that already have one.
- Both end up in `mcp_change` (`summary`, `suggestion`) and can be undone from Settings › Claude: the previous summary returns as it was, suggestions still pending disappear. A summary rewritten afterwards (by Claude, by the engine or by hand) cannot be undone: IAGO explains this instead of losing that work. Before saving, automatic summarization checks again that no summary from Claude or manual edit has arrived in the meantime.

## Screenshots (ADR-0072)
- `get_item` includes the **text** of the screenshots at their minute.
- `get_screenshots` returns the **images** as MCP `image` content (JPEG, long side 1,568 pixels, at most 8 per call), only if the user enables "Also share screenshot images with Claude" (`claude.share_screenshots`, off by default).

## Writes (ADR-0044, ADR-0047)
1. Every write tool works **in two steps**: without `confirmation` it returns only a **preview** (what, where, what it is linked to, which entry it supersedes).
2. Claude shows it to the user; only with confirmation does it call the tool again and the write happens.
3. The server writes directly to the archive with a write connection opened at the first write; only audio, video and Teams transcripts go through the app's inbox (`MCPInbox`), which converts and transcribes them like a drag and drop.
4. Every write can be **undone** and carries the "via Claude" mark.

## Connecting Claude
In **Settings › Claude** IAGO prepares the configuration for Claude Desktop or the command for Claude Code, with a name for the connection and the project (or projects) to expose. The user instructions are in the [Claude](/en/guida/claude) chapter of the guide.

::: warning Where the data goes
What Claude reads reaches Anthropic under the terms of the user's Claude account. That is why it is off by default and enabled project by project (ADR-0058).
:::
