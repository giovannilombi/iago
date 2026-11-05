# ADR-0095 — Claude as an alternative on every Mac, with the steps, and restarting Claude Desktop

- Status: accepted
- Date: 2026-11-05
- Amends: ADR-0078 (Claude suggested on slow Macs)
- References: ADR-0043 (MCP server), ADR-0071 (summaries and suggestions made by Claude); user request of 2026-11-05

## Context
- The box suggesting Claude for summaries and suggestions appeared only on Macs up to 16 GB (ADR-0078). On Macs with more memory it was missing, although Claude remains a useful alternative.
- In the summary the box sat above the *Generate summary* button, and often the only useful button was *Use the Mac's engine*: it was not clear how to get it done with Claude.
- Claude Desktop starts IAGO's MCP server only when it opens. A project just made readable is not visible until Claude Desktop is restarted, and nothing said so.

## Decision
- **Every Mac:** up to 16 GB the box stays a *Tip*, in orange. With more memory it becomes an *Alternative*, with neutral colours, plain buttons and the text "The Mac's engine works well on this Mac".
- **Position:** in the summary the box sits at the bottom, after *Generate summary* and the engine warnings. First comes the way with the Mac's engine, then Claude.
- **Steps:** under *To do it with Claude* the box lists four steps, each with a done mark and the button it needs:
  1. item in a project;
  2. Claude connected to IAGO, and to this project (*Connect Claude…*);
  3. project allowed to Claude (*Allow*);
  4. *Ask Claude for the summary*.

  *Not here: I use the Mac's engine* and *Don't show again* become two links at the bottom. Suggestions stay on a single line.
- **Hidden box:** after *Don't show again* or *Not here* a thin strip remains, "Alternative: you can also make the summary with Claude." (or the suggestions), with *See how*, which opens the whole box again for that item.
- **Restarting Claude Desktop:** when a project becomes readable by Claude and Claude Desktop is open, IAGO shows the alert *Restart Claude Desktop*, with *Restart Claude* (IAGO quits it and opens it again) and *Later*. It applies everywhere access is allowed: Settings › Claude, project or client settings, the box, *Copy for Claude*. If Claude Desktop is closed there is no need, and the alert does not appear.

## Consequences
- On every Mac it is clear how to make the summary with Claude, without it looking like the only way.
- Whoever allows a project knows at once why Claude does not see it yet, and can fix it with one click.
