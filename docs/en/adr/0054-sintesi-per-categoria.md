# ADR-0054 — Summaries based on the category

- Status: accepted (flow and rules approved by the user on 2026-10-21; additional categories to be decided)
- Date: 2026-10-21
- Spec references: categories (sec. 8); ADR-0046 (key points), ADR-0048 (local engine); user requests 2026-10-13, 2026-10-16, 2026-10-21

## Context
Call categories (1to1, Kickoff, Progress review, Workshop, Review/Demo, Sales, Internal, Other) exist because the user wants different summaries for each type of meeting, as Plaud does. Now the local engine is there (ADR-0048).

The user does not want to reinvent the wheel. Two open source projects already make summaries with templates per meeting type and a local model:
- **Meetily** (github.com/Zackriya-Solutions/meeting-minutes, MIT, © 2024 Zackriya Solutions): 6 templates in JSON, each with sections that have a title, an instruction for the model, a format (paragraph, list, short text) and, for lists, table columns;
- **Hyprnote**, now Anarlog (github.com/fastrepl/hyprnote, MIT, © 2023 Fastrepl): 17 templates (1:1, project and client kickoff, brainstorming, sales discovery, design review, retrospective, postmortem…), each with sections that have a title and a description.

Plaud is not open source: its templates cannot be reused.

## Decision
### Summary templates
- **Format:** the same JSON as Meetily (`name`, `description`, `sections[]` with `title`, `instruction`, `format` and optional `item_format`). This way templates written for Meetily can be imported and exported.
- **Content:** the Meetily and Hyprnote templates, translated and adapted to the 8 categories, with attribution in `docs/licenses.md` as the MIT license requires:

| Category | Based on | Sections |
|---|---|---|
| **1to1** | Hyprnote "1:1 Meeting" | Updates · Wins and challenges · Goals and progress · Feedback, both ways · Commitments (Who · What · By) |
| **Kickoff** | Hyprnote "Project Kickoff" and "Client Kickoff" | Overview (scope, goals, deliverables) · Success criteria · People and roles · Timing and milestones (Milestone · Date) · Risks and dependencies · How updates happen · Next steps |
| **Progress review** | Meetily "Project Sync" | Progress · Milestones and status (Milestone · Status · Forecast) · Risks and countermeasures (Risk · Impact · Countermeasure · Who) · Decisions (Decision · Reason · Minute) · Tasks (Who · What · By) |
| **Workshop** | Hyprnote "Brainstorming Session" | Session goal · Ideas that emerged · Most promising ideas · Criteria to evaluate them · Next steps |
| **Review/Demo** | Hyprnote "Technical Design Review" | What was presented · Feedback (Point · Feedback · Who) · Requested changes · Approved and to be revised · Next steps |
| **Sales** | Meetily "Client / Sales Meeting" and Hyprnote "Sales Discovery Call" | Client context · Current situation and problems · Goals and success criteria · Budget, timing and conditions · Objections and doubts · Competitors mentioned · Next steps (Who · What · By) |
| **Internal**, **Other** | Meetily "Standard Meeting Notes" | Summary · Decisions · Tasks (Who · What · By · Minute) · Discussion highlights |

- **In every summary:**
  - **In brief**, 3 lines at the top;
  - **date and participants taken from IAGO's data** (item, people, calendar), not from the model: unlike Meetily, the model does not have to guess them.
- **Categories stay open:** the user creates, renames, archives and reorders them as today.
- **Template collection:** IAGO includes all the templates of the two projects, translated and adapted: 6 from Meetily and 17 from Hyprnote, with duplicates merged. Each category uses a template from the collection:
  - the 8 current categories start with those in the table above;
  - a new category chooses its own when created, with a suggestion based on the name;
  - "No summary" is a valid choice.
- **Editable templates** in Settings › Categories: sections, instructions and columns. "Restore original" goes back to the collection's template.

### Reliability rules
They are the same as for key points (ADR-0046):
- each point carries the **minute** it comes from. IAGO verifies that the quoted sentence is really there, with identical numbers; if it does not find it, the point is discarded;
- a section without content says **"Not mentioned"**: the model does not have to fill it;
- **long calls:** 10-minute chunks, first a summary per chunk and then an overall one;
- Italian; no made-up names for speakers;
- decisions and tasks already in the key point log are linked, not rewritten.

### When it starts
- **At the end of transcription, on its own, only if the item already has a category** and the engine is installed.
- **Without a category** it does not start. The **Summary** block is there anyway, always visible in the detail pane, with:
  - the message "Summary not yet available";
  - the choice of category (which is also the item's category);
  - the **"Generate summary"** button.
- **Without the engine** the block explains that the local engine is needed, with the link to Settings › Engine.
- **Changing category** when the summary is already done, the block offers "Regenerate with the «…» template". It does not regenerate on its own. If the summary was edited by hand, it asks for confirmation before replacing it.
- **While generating it**, the block shows progress by chunks, which also appears in Activity (ADR-0055).

### Data and performance
- `summary` table, migration `v17-summaries`, with a backup before installation. It contains:
  - item, category, summary template version;
  - Markdown text;
  - engine used;
  - "edited by hand";
  - date.
- The summary is included in search, exports, Obsidian, Ask and Claude (MCP, read-only).
- **Queue job** `summary` (QoS `.utility`, one at a time, after transcription). Expected times for a 30-minute call, on the user's Mac:

| Model | Measured time (29-min call, 2026-10-21) | Memory | Outcome |
|---|---|---|---|
| Qwen 3.5 4B | 112 s | 3.3 GB | few points kept (6), many discarded: weak |
| Qwen 3.5 9B | 167 s | 6.1 GB | good: 20 points, tasks repeated "who" (fixed) |
| Gemma 4 12B | 325 s | 12.4 GB | the best: correct decisions, exact figures |

- Local engine only, no Apple Intelligence (ADR-0048).

## Consequences
- Categories serve a purpose and the summary has the right form for the type of meeting, without inventing templates from scratch.
- Quality depends on the transcript. Before turning it on by default it is tried on 2-3 real calls of different categories, with an evaluation sheet.
- Compared with Meetily: quote verification, date and participants taken from the data, "Not mentioned" instead of sections filled in by force.

## Fine-tuning after the first test (2026-10-21)
- The **overview** sections (paragraph format: Context, Overview, Progress…) summarize the whole chunk and rarely have a sentence to quote. They stay without a minute, as long as every number they contain is said in the chunk.
- The quote can span 3 consecutive turns (for key points it stays 2).
- Values like "not specified" become "—"; in tables the text does not repeat who and when.
- The "Standard meeting" template no longer has the "Summary" section, which duplicated "In brief".
- **Categories on two levels:** the main ones are always visible; the families (Agile, Management, People, Operations) are turned on in Settings › Categories and appear as submenus. "Sales" becomes "Client/Sales"; "Customer discovery" is added among the main ones.
- **Sidebar:** clients are small-caps headers, categories and tags leave the sidebar. They are reached from "Categories and tags", from search (`#tag`, `categoria:`), from the detail pane (click on category or tag) and can be pinned in "Pinned".

## Change of 2026-10-21 (2): from the test on three real calls
- **Instructions to the model:**
  - "text" is a third-person summary of at most 15 words, not the sentence as spoken;
  - the quote is short;
  - at most 4 points per section and per chunk;
  - no small talk, no **personal matters** (health, family);
  - **decisions** are only those made in the meeting, not stories.
- **IAGO's checks:**
  - it discards points that coincide with the quote or start in lowercase (copied speech);
  - it removes the repeated name ("Mario deve…" when the Who column already says Mario).
- **Reading the answers:**
  - compact JSON and answers up to 2,500 tokens;
  - if the JSON is truncated, the last complete point is kept;
  - each `{"titolo": …}` section is read on its own;
  - if the brackets are wrong, texts and quotes are read by patterns.
- **Minimum engine:** 9B (ADR-0048, change of 2026-10-21).

## Change of 2026-10-27 (ADR-0071)
- **Claude** can also write the summary, via MCP (`set_summary`), in the category's template and with the same checks on quotes: it is no longer read-only.
- The text of the call's **screenshots** (ADR-0072) is included in the lines read, at its minute.
