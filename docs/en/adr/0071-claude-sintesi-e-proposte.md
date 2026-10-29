# ADR-0071 — Summaries and suggestions made by Claude

- Status: accepted
- Date: 2026-10-27
- References: ADR-0043 (MCP server), ADR-0044 and ADR-0047 (writes with preview), ADR-0054 (summaries per category), ADR-0009 (the engine suggests, the user confirms), ADR-0058 (nothing leaves without the user's choice), ADR-0070 (provenance); user's directions of 2026-10-27

## Context
- On Macs with little memory the local engine is slow or not enough; Claude writes higher-quality summaries and suggestions.
- With MCP it is always Claude that calls IAGO: IAGO cannot delegate a job to it on its own. Delegating means the user opens Claude and asks it.
- The biggest risk is that Claude works on the wrong item, or cannot find it, and that the user gets frustrated.
- ADR-0054 gave Claude read-only access to summaries.

## Decision
- **Finding the item:**
  - in the detail pane, **Copy for Claude…** copies the reference (`item_id`, title, date, project) and a ready-made request: *for the summary*, *for suggestions*, *reference only*. Before copying, IAGO checks that the project is readable (and writable, if needed) and, if it is not, explains it and enables it with one click;
  - the `recent_items` tool lists the latest items of all readable projects, for "yesterday's call"; if there is more than one candidate, Claude asks which one.
- **Summaries (`set_summary`):** Claude writes in the **category's template** (`summary_template`) and each point carries the **exact quote**. IAGO assembles the summary with the same code and the same checks as the local engine: it verifies each quote and links the point to its minute, discards points without a quote or with a quote it cannot find, writes «Not mentioned» in empty sections. No free text: Claude's summaries have the same form and reliability as the Mac's.
- **Suggestions (`propose_suggestions`):** decisions and tasks with a verified quote, and tags, become **pending suggestions** (ADR-0009), not confirmed key points.
- **Like every write** (ADR-0047): preview with the points kept and discarded, the user's OK, confirmation; access log; can be undone from Settings › Claude (the previous summary goes back to how it was, pending suggestions disappear).
- **Coexistence with the local engine:** automatic summaries skip items that already have a summary; «Regenerate» asks for confirmation before replacing Claude's; the engine and Claude do not delete each other's pending suggestions.
- Provenance («Summarized by Claude», «Recommended by Claude») follows ADR-0070.

## Consequences
- Changes ADR-0054: Claude can write the summary, with IAGO's checks.
- What Claude reads goes to Anthropic according to the user's account, as today: only for the projects the user makes readable (ADR-0058).
- Network calls do not change: it is Claude that talks to Anthropic, IAGO remains a stdio server.
