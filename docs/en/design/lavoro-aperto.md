# IAGO — Open work: two modes, Track and Manage

Design of October 28, 2026, implemented in 1.1.0-beta. Related decision: [ADR-0074](../adr/0074-lavoro-aperto-traccia-gestisci.md).

## In one sentence
IAGO remains the memory of work, and also keeps track of **what is open**: tasks, open questions, risks, requests. **All the types are always there.** Only how much management you see changes, project by project:
- **Manage** (default): fine-grained statuses, fields, kanban and complete overview;
- **Track**: as simple as 1.0.

Update of October 28, 2026, during testing: the mode is chosen per project and Manage is the default; the views are redesigned as «how to look × what to show» (ADR-0075).

Update of October 29, 2026 ([ADR-0076](../adr/0076-modalita-inbox-elementi.md)): the two modes are now truly distinct. **Track mode** (simple and quick) has Short overview, Items, Timeline and Graph, tasks to check off, no Kanban and no «Show»; **Manage mode** (complete) has everything. «To do» becomes **Inbox** at the top of the sidebar, «Unfiled» becomes «Unfiled items», «List» becomes «Items», «Map» goes back to «Graph». The Kanban of everything also includes projects in Track. Where this document says otherwise, ADR-0076 applies.

You switch from one to the other without losing anything.

## Why
- Today the key points are decision, task and milestone. A task has only text, people and the open/done status: there is no explicit owner, no due date, no "waiting for".
- The "open question" type exists in the model (`openQuestion`, ADR-0014) but isn't visible.
- IAGO is used both by operational staff and by PMs. PMs need to know **what is open, whose it is, by when, what is blocking**, and the timeline doesn't say that.
- We don't want a worse Jira: no sprints, no estimate calculations, no workflows to configure.

## The types
Two natures. **Memory** records what happened and isn't something you "do". **Work** is open until someone closes it.

| Nature | Type | Mark | `kind` | What it is |
|---|---|---|---|---|
| Memory | **Decision** | ◆ green seal | `decision` | something decided; it holds until another one replaces it |
| Memory | **Milestone** | ⚑ blue flag | `milestone` | an important fact: signature, delivery, kickoff |
| Work | **Task** | ○ orange circle | `action` | something to do, also with a checklist (multiple to-dos) |
| Work | **Open question** | ? purple dot | `open_question` | a question waiting for an answer |
| Work | **Risk** | ⚠ red triangle | `risk` | what can go wrong, with severity; if it happens it becomes an issue |
| Work | **Request** | ✉ light-blue envelope | `request` | what the client asks for; it is accepted or rejected |

Notes remain notes: they can be **promoted** to any type, as today.

## How they connect: three links
1. **Supersedes / closes** (today's link, ADR-0052). A more recent entry closes an older one. The line reads it with the right verb for the two types:

   | Who | → whom | Reads | Effect on the older entry |
   |---|---|---|---|
   | Decision | → Decision | «replaces» | Superseded |
   | Decision | → Open question | «answers» | Answered (the decision is the answer) |
   | Decision or Task | → Request | «accepts» | Accepted |
   | Milestone or Decision | → Task | «completes» | Done |
   | Milestone | → Milestone | «replaces» | Superseded |
   | any | → any other case | «supersedes» | closed |

   ADR-0052 rules unchanged: multiple links, no cycles, removing the link reopens the entry.
2. **Derived from.** An entry is born from another and remembers it:
   - tasks derived from an accepted request;
   - a mitigation task derived from a risk;
   - an open question derived from a decision.

   It doesn't close anything: the risk stays open until you close it.
3. **Depends on.** «Blocked until X is closed». When all the entries it depends on are closed, it goes back to how it was.

**Checklists** are not a link: they are the sub-entries of a task (see below).

## Statuses
**Memory** entries have today's statuses: active, superseded, cancelled.

**Work** entries have six statuses. In Track mode you see four:

| Status (Manage) | Seen in Track | `status` |
|---|---|---|
| To do | Open | `active` (as today: no data migration) |
| In progress | Open | `in_progress` |
| Waiting (for whom, until when) | Waiting | `waiting` |
| Blocked | Open, with the «blocked» mark | `blocked`: automatic if a dependency is open, or by hand |
| Done | Done | `done` |
| Cancelled | Cancelled | `cancelled` |
| *(closed by another entry)* | Answered / Accepted / Done, depending on the verb | `superseded`, as today |

**Closures with an outcome**, in the `outcome` field:
- **Open question:** it is closed with the **answer**. The answer is written, or taken from a sentence of a call or an email with its source. The «Becomes a decision» button creates a decision that *answers* the question.
- **Request:** it is closed as **accepted** (it creates one or more tasks *derived from* it, or a decision that *accepts* it), **rejected** (with the reason) or **converted** into another type.
- **Risk:** it has a **severity** of high, medium or low. It is marked **«Became an issue»**, with the date, and the history stays in the same entry. It is closed as **resolved** or **no longer relevant**.

## Fields
All optional.

| Field | Track | Manage | Notes |
|---|---|---|---|
| Title, type, description, date, source, people, tags, stream | ✓ | ✓ | as today |
| **Owner** | ✓ | ✓ | a person already known or a new one; «Me» always at the top |
| **Due date** | ✓ | ✓ | |
| **Waiting for** (person, until when) | ✓ | ✓ | |
| **Checklist** | ✓ | ✓ | sub-entries to check off |
| Priority (high, medium, low) | — | ✓ | |
| Depends on | «blocked» mark | ✓ | |
| Estimate, start date | — | ✓ | for reference only, no calculations |
| Recurrence (day, week, month, year) | — | ✓ | once one is closed, the next is created |
| Free column of the kanban | — | ✓ | |

**People.** You choose among those IAGO already knows (speakers, email contacts, people in key points, voices) or write a new name. On a new name, IAGO checks for similarities: «Did you mean Marco Rossi?». People are the existing person-type `entity` records.

In **Track** a Manage field that is already filled in isn't lost: it stays saved and a small icon says «has details in Manage».

## The two modes
| | **Track** | **Manage** (default) |
|---|---|---|
| Types | all | all |
| Visible work statuses | a checkbox (done or not); «waiting» follows «Waiting for» (ADR-0076) | all six |
| Entry detail | title, type, owner, due date, waiting for, checklist, description | also «More details»: priority, dependencies, estimate, start, recurrence |
| Views | Short **Overview**, Items, Timeline, Graph (can be turned off); **Inbox** | in addition **Kanban** (project and global), «Show», complete **Overview**, filters by person and priority |
| Morning notification | available, off | available, off |
| Engine and Claude suggestions | all types | all types |

- **Where you choose:** the «Manage ▾» pill next to the project name, and Settings › Projects.
- **Per project:** a project in Track is seen in Track; its entries are in the Inbox and in the kanban of everything, each in the mode of its project (ADR-0076).
- **Kanban:** in Manage it is on by default and has its own switch. When off, the free columns and the positions stay saved.

## The views

### Timeline (both modes)
It remains the **memory of the project**: sorted by date, each entry at its date (of the decision, of the milestone or of the moment the work entry came up). **Closing an entry doesn't create a new line**: it changes its appearance.

| Status | How it looks |
|---|---|
| Open | the type's mark and color, normal text; owner and due date in small type |
| Overdue | the due date turns red |
| Waiting | label «waiting for Anna · by Nov 5» |
| Blocked | label «blocked» |
| Done | green ✓, gray text **not struck through** (it is a positive outcome) |
| Answered / Accepted / Rejected | one line: «? Which provider? → *We use Azure AD*», «accepted», «rejected: over budget» |
| Superseded / Cancelled | gray **struck-through** text, as today |

An entry closed by another one **sits under it** if it is from the same day, as superseded decisions do today. Otherwise it stays at its date with «→ closed by …».

Example (most recent first):
```
Nov 20  ⚑ Milestone  SSO order signed                   completes ↓
          └ ✓ Task      SSO quote · Marco                done
 Nov 8  ◆ Decision   We use Azure AD                    answers ↓
          └ ? Which SSO provider?                        answered
 Nov 3  📞 Call «Weekly progress review»
        ✉ Request    SSO login for employees            accepted → 1 task
        ○ Task       SSO quote · Marco · by Nov 10      (derived from the request)
```

### To do (inbox, both modes)
In the sidebar, always present. It shows only the open work, of all projects:
- **my entries:** overdue, today, this week, later, no date;
- **Waiting on others:** the waiting entries I follow, with the promised date and the delay;
- **Suggestions to confirm** from the engine and from Claude;
- the projects' **pinned checklists**.

Closed entries leave the view. **«Show closed»** brings them back.

Example:
```
To do                                           [ Show closed ]
Overdue
  ○ Send the SSO quote             Portal · 2 days ago
Today
  ? Which SSO provider?            Portal · Me
This week
  ⚠ Supplier delay (high)          Logistics · Fri
Waiting on others
  ○ Final files                    Acme · Anna · by yesterday
Suggestions to confirm (3)
Pinned checklists
  ☐ Final delivery (4/7)           Portal
```

### Project overview (both modes)
One page per project (and per client and stream):
- **Track, short version:** open entries by type, upcoming due dates, recent decisions and milestones, pinned checklists.
- **Manage, complete version:**
  - **status and progress:** open and closed by type, overdue, blocked, upcoming milestones;
  - **what changed** since the last time you opened it;
  - **risks by severity, open questions, waiting on others;**
  - **written status report,** generated by the engine or by Claude, to copy into an email. The citations are verified as in summaries (ADR-0054).

### Kanban (Manage only)
- **One board per project, client and stream, and a global one** with filters by project, person and type.
- **Fixed columns:** To do, In progress, Waiting, Blocked, Done. Moving an entry from one fixed column to another **changes its status**.
- The user's **free columns**, added after the fixed ones (for example «To discuss on Friday», «Ideas»). Putting an entry in a free column **doesn't change its status**: it serves to group it. Each board has its own free columns.
- **The Done column shows the completed entries.** Those closed more than 14 days ago are archived: at the bottom of the column a small line says «Tasks closed 14+ days ago archived» with **Show all**. After the click it shows them and the line becomes «Archive tasks closed 14+ days ago». The choice is remembered.

```
To do   │ In progress      │ Waiting           │ Blocked  │ Done  ║ To discuss
        │ ○ SSO quote      │ ? Which provider  │          │       ║ ✉ Mobile app
        │   Marco · 11/10  │   waiting client  │          │       ║
```

### Key points and Graph
They stay as today, with the new types:
- the new types appear in the type filter;
- in the graph each type has its own shape;
- the «derived from» and «depends on» links are dashed.

## Morning notification
A single alert, at the chosen time, on working days: «3 due today, 2 overdue, 1 wait expired». A click opens To do. It is turned on and off in Settings; by default it is off.

## Engine and Claude suggestions
- **The engine** suggests all types in both modes (ADR-0049), each with the sentence it comes from:
  - open questions;
  - risks with severity;
  - client requests;
  - tasks with owner, due date or «waiting for», when the call says so («Anna will send us the files by Friday»).
- A suggestion can also **close** an open entry, for example «this decision answers *Which provider?*», as it suggests supersessions today.
- **Claude, via MCP:**
  - `add_decision`, `update_decision` and `list_decisions` accept the new types, statuses and fields;
  - `propose_suggestions` accepts the new types (ADR-0071).

  Preview and undo work as today.
- Suggestions of the new types are active right away; the test bench on real calls then serves to improve them.

## Exports
- **Project Markdown and Obsidian:** the new types and statuses, with owner, due date, outcome and checklist (`[Rischio · alta · Aperto]`, `[Punto da chiarire · Chiarito] → risposta`).
- **Status report:** can be copied as text.

## Data
One migration (`v21-work`) that **adds** and changes nothing of what is there.

**New columns in the `decision` table:**

| Column | Type | Use |
|---|---|---|
| `owner_id` | text, → `entity` | owner |
| `due_at` | date | due date |
| `waiting_on_id`, `waiting_until` | → `entity`, date | waiting for |
| `priority` | integer (1 high, 2 medium, 3 low) | |
| `starts_at`, `estimate` | date, text | for reference only |
| `severity` | text (`high`, `medium`, `low`) | risk |
| `happened_at` | date | risk that became an issue |
| `outcome` | text | answer, reason for rejection, outcome |
| `outcome_kind` | text (`answered`, `accepted`, `rejected`, `converted`, `resolved`, `irrelevant`) | |
| `derived_from_id` | → `decision` | derived from |
| `recurrence` | text (`daily`, `weekly`, `monthly`, `yearly`) | |
| `closed_at` | date | when it was closed (for «Show closed» and for the overview) |

**New tables:**
- `decision_dependency (blocked_id, blocker_id)`;
- `checklist (id, project_id, name, pinned, sort)`, for project lists;
- `checklist_item (id, decision_id | checklist_id, text, done, sort)`;
- `board_column (id, scope, name, sort)` and `board_place (scope, decision_id, column_id)`, for the free columns of each board;
- `project.work_mode` (null = Manage, `track` = Track).

`kind` and `status` are text: the new values (`risk`, `request`, `in_progress`, `waiting`, `blocked`) don't require converting the data. Today's tasks stay `active` (To do) or `done`. All tables have the sync columns and the change log (ADR-0008), ready for sharing.

## Testing without risk
- **The code stays separate.** Work happens on the `feat/lavoro` branch, one PR per phase into that branch, with CI. `main` stays today's version, for Gianluca too. It is merged into `main` only after approval.
- **The real archive is never touched.** The `v21` migration changes the database, and a previous version of IAGO wouldn't be able to read the new statuses. The `scripts/try-branch.sh` script:
  1. asks you to quit IAGO;
  2. copies the archive into a test folder (`~/IAGO-prova/`);
  3. builds the branch and opens it on that copy (`-IAGODemoRoot`, ADR-0061).

  The archive key is the same in the Keychain, so the copy opens with all its contents.
- **Going back to today's version** means closing the test build and reopening normal IAGO: the archive is as it was. The copy can be thrown away or redone whenever you want.
- **Warning:** while testing, new recordings go into the copy. For real work, use normal IAGO.

## Version and restore
- Everything goes together into **1.1.0-beta**, on the `feat/lavoro` branch, with the documentation updated.
- **Restore point:** the `v1.0.1-beta` tag (code, guide and documentation) and the `release/1.0.x` branch. If 1.1 is abandoned, work resumes from there with the 1.0.x series.
- 1.1.0-beta goes into `main` only after approval; until then it is tested with `scripts/try-branch.sh` on a copy of the archive.

## On hold (goals to reopen)
- **Calendars:** Mac Calendar, Google and Microsoft in both directions. Google and Microsoft need an ADR with a network exception (login, token in the Keychain, access log); company accounts may require IT approval, Google app verification.
- **Plan the day:** a guided step in the morning (any.do style) on today's, overdue and waiting entries.
- **Sending tasks to others** before sharing (phase 4): by email, message or file to import.
- **Sprints and estimate calculations:** excluded by choice.
