# IAGO — Project status

> The restart point for anyone working on IAGO, people and Claude Code sessions.
> **It must be updated at the end of every piece of work**, in the same PR: what changed, what remains open.
> Last update: **October 29, 2026**.

## In brief
- **Version:** 1.2.5-beta on `main` (tag `v1.2.5-beta`): app, guide, site and documents in Italian and English (ADR-0077), with open work revised (ADR-0074, ADR-0075, ADR-0076). Restore points: `v1.2.4-beta`, `v1.2.3-beta`, `v1.2.2-beta`, `v1.2.1-beta`, `v1.2.0-beta`, `v1.1.0-beta` and `v1.0.1-beta` with the `release/1.0.x` branch (1.0 series). To go back with an archive already opened, you need the backup made before updating. The first distributable version will be without `-beta`.
- **Repositories:**
  - `giovannilombi/iago`, private, born with a single commit "IAGO 1.0.0-beta" (tag `v1.0.0-beta`);
  - `giovannilombi/iago-archivio`, private, with the previous development history (it contains real test data: it must never be made public).
- **Authors:** Giovanni Lombi; from the versions after 1.0.0-beta, Giovanni Lombi and Gianluca Sestito (ADR-0065).
- **Phases:** 0, 1, 2 and 3 developed and merged into `main`. Phase 4 (sharing) is waiting for a decision (ADR-0057).
- **Automated tests:** 309 in the packages, all green (1.2.5-beta).

## What IAGO does today
The full description is in the [README](../../README.en.md). In short:
- it records calls on two tracks (system and microphone) and transcribes them on the Mac (whisper.cpp or Parakeet);
- it imports emails, documents, PDFs, images, Teams transcripts, also from watched folders;
- it organizes by client › project › stream, with categories (which decide the shape of the summary) and tags;
- it extracts key points (decisions, tasks, milestones) with their evolution over time;
- summaries by category, search by words and by meaning, "Ask IAGO" with sources and "Widen context";
- MLX local engine inside the app, optional Claude via MCP;
- recording bar and listening bar, Activity, built-in guide, tour, updates with Sparkle.

## Open, in order of priority
0. **Testing of 1.2.0-beta** (open work, ADR-0074 and ADR-0076, [`docs/design/lavoro-aperto.md`](design/lavoro-aperto.md)): tests 10i of [`docs/prove-tester.md`](prove-tester.md) on the user's Mac (installed on October 29), then refinements. On hold, to be reopened: sync with calendars (Mac, Google, Microsoft, a network ADR will be needed), Plan the day, sending tasks to others before phase 4, tuning of open-work suggestions on real calls.
1. **Technical review** by the colleague and decision on distribution.
2. **Acceptance tests** with [`docs/prove-tester.md`](prove-tester.md), one "Prove" issue per tester (see [README-collaborators](../../README-collaborators.en.md#6-testing)).
3. **Live checks still to do:**
   - the Teams microphone works while IAGO records (after ADR-0053 was withdrawn);
   - the IAGO icon in macOS notifications;
   - the October 27 additions, sections 10b-10h of [`docs/prove-tester.md`](prove-tester.md), with tuning of the voice threshold on real calls (10h): engine queue and memory on a 16 GB Mac, screenshots and shortcuts in the real app (with the Screen Recording permission given to IAGO), summaries and suggestions made by Claude Desktop, DMG and updates.
4. **Proposed ADRs, to be decided:**
   - ADR-0057, shared projects through a cloud folder (design in [`docs/design/sync-cartella-condivisa.md`](design/sync-cartella-condivisa.md)); once accepted it supersedes the ADR-0012 backend and phase 4 opens;
   - ADR-0067, MiniCPM instead of Qwen 3.5 4B or in addition to it: tests are needed. A local vision model (MiniCPM-V) will be considered only if the OCR of screenshots is not enough (ADR-0072).
   - Single extraction for suggestions and summaries (today the same call is read twice): only if the benchmark on real calls shows the same quality.
5. **Distribution** (ADR-0059, ADR-0060, ADR-0065): without a paid Apple account the app is not notarized and whoever installs it has to use "Open Anyway". It is distributed with the **DMG** from `scripts/release.sh`. **To be verified first** on a clean Mac or user account: "Open Anyway" only once, update with Sparkle without a new block and with permissions kept, duration of the free certificate and what happens when it expires. To distribute: public repository, `scripts/release.sh 1.0.0 --github`, README Versions table, enabling GitHub Pages for the site (ADR-0068) and `https://giovannilombi.github.io/iago/` as "Website" in the repository's About section.
6. **Later:**
   - in-depth tests of transcription quality on real calls (engines, diarization);
   - room voices (ADR-0031) in voice recognition;
   - graph refinements.

## Latest changes
- **2026-10-30:** version **1.2.5-beta**.
- **2026-10-30, IAGO's and Teams' transcripts side by side** (ADR-0078): attaching Teams no longer replaces IAGO's transcript. The two sit in two tabs; Teams' minutes are plain text, with no link to the audio. Only one is the main one for summaries, suggestions and search, they swap with a click and each can be deleted later. Tests 10o.1–10o.5.
- **2026-10-30, «Use Claude» tip on Macs up to 16 GB** (ADR-0078): under Summary and Suggestions a box copies the request and opens Claude, saying what is missing (connection, consent, project) without enabling anything by itself. Settings › Engine › *Summaries and suggestions* can choose Claude for everything. Tests 10o.6–10o.8.
- **2026-10-30, ADR-0079 proposed:** analysis for also using Claude Code, Gemini, Gemini CLI, ChatGPT and Codex CLI, to start from. Only tools that start IAGO locally, separate consents per assistant.
- **2026-10-30:** version **1.2.4-beta**.
- **2026-10-30, Inbox with two badges** (ADR-0076, amendment): the red badge added up due dates and suggestions, and the 38 test suggestions could not be seen in the Inbox (only a link to Key points). Now the **red** one (!) counts what needs action now, that is late, today, no owner and overdue waits. The **yellow** one (✦) counts the suggestions to confirm. The Inbox has three blocks (Do now, Suggestions to confirm, Later), with the number in the header in the same colour, and suggestions are confirmed or dismissed there. Tests 10n.
- **2026-10-30, speaker names** (ADR-0073, amendment; migration `v22-speaker-names`): a name typed and left with a click was lost without warning. Now it is confirmed with Return or ⏎, and the unconfirmed field is red and stays. Before applying it IAGO asks about similar names (typos, one name inside the other, nicknames like Lello/Antonello) and remembers the answers. The same name for two speakers offers *Join*, undone with *Separate*. *Generate summary* and *Regenerate* ask whether to name them first. Tests 10n.6–10n.9.
- **2026-10-29, CI by hand only:** the GitHub Free minutes ran out, so every workflow runs only when the user asks; before every PR, Claude Code asks whether to run it and what that implies. The network API check now runs with `scripts/test-packages.sh`.
- **2026-10-29:** version **1.2.3-beta**.
- **2026-10-29, tags suggested only from the item** (ADR-0049, change): the engine picked tags of other calls from the list with no ground in the recording. Now every tag must have its sentence in the text, or its words in the text.
- **2026-10-29, rights** (ADR-0065, change): Giovanni Lombi up to 1.3.x-beta, Giovanni Lombi and Gianluca Sestito from 1.4.0-beta; shorter README, site footer with both and a link to the credits.
- **2026-10-29, slow window** (the window stuttered when dragged, a second to change section). The main thread was always busy with two jobs:
  - the background round restarted without pause, because the one-minute timer, when cancelled, woke it again (a bug present since 1.0.0-beta, heavier as the archive grew);
  - the search for Teams' microphone button (Accessibility) walked up to 6,000 elements every 3 seconds on the main thread. It now runs away from the main thread, and every 20 seconds when Teams does not use the microphone.
- **2026-10-29:** version **1.2.2-beta**, **Italian and English** (ADR-0077):
  - language chosen at first launch and in Settings › General, with restart;
  - about 1,700 interface texts translated in the String Catalog;
  - English guide with its own screenshots;
  - site with English under `/en/`;
  - all documents translated (`docs/en/`, `*.en.md`, ADRs included);
  - summaries, suggestions, status reports and answers in the app's language (English summary templates);
  - starter example and default categories renamed with the language;
  - glossary `i18n/glossary.tsv`;
  - `scripts/i18n.py check` in the `pre-commit` hook and in CI.

  Rebuilt ADR-0054 and ADR-0059, left truncated by an earlier commit.
- **2026-10-29:** version **1.2.1-beta** (tag `v1.2.1-beta`): 1.2.0-beta with the fixes to the sidebar, the Kanban panel and the guide.
- **2026-10-29:** after a check of all the screenshots: with "Ask IAGO" open on a wide view (Overview, Kanban, Graph) the sidebar moved up under the window buttons, because the panel animation affected the whole window (now it animates only the floating button); in the panel on the right of the Kanban the buttons are no longer cut off (date below). Guide: import from the project in the Emails and documents chapter, main window in Getting started. Screenshots redone and all checked; the tour takes `-IAGODemoShots` to redo only some screenshots.
- **2026-10-29:** **1.2.0-beta** merged into `main` with the tag `v1.2.0-beta` (PR #11) and installed on the user's Mac. A client's mode and projects with a manually chosen mode are stored in the archive (settings), so they carry over with the backup; only Graph turned off and windows closed forever remain in `UserDefaults`. README: at the top, the pointer to the official documentation (VitePress site).
- **2026-10-29:** 1.1.0-beta, second revision after testing (ADR-0076, decided on a proposal with example windows): **Track mode** truly simple (Short overview with To do, Keep an eye on, Latest decisions and milestones; tasks to check off; no Kanban or "Show"; Graph can be turned off; all types) and **Manage mode** complete; name, icon and color of the modes in the pill and in the sidebar; window on the first visit to a project or client ("OK" / "Don't show again"). **Inbox** instead of "To do", at the top with the red badge; "Unfiled items"; view bar `[Overview] [Items] │ [Timeline · Kanban · Graph]`; "Import files and items…" at the bottom of "Add", with direct import into the project. Everyone's Kanban includes projects in Track. The demo tour closes by itself; guide screenshots redone, new `inbox.png`, `modalita.png`, `importa.png`, `riepilogo-breve.png`.
- **2026-10-28:** 1.1.0-beta, after the user's first test: Track / Manage per project, Manage as default (pill "Manage ▾" next to the name and Settings › Projects; removed the choice in General and the step in the welcome tour). View bar redesigned (ADR-0075): Overview on its own, then List · Timeline · Kanban · Map, and "Show: Everything / Materials / Key points"; Kanban, Overview and Map full-window with the panel on the right (✕ or Esc); Overview redesigned for the wide window (band of numbers, what to do on the left, context, summary and checklists on the right); last view remembered per project. Morning notification off until turned on. Guide screenshots redone from the demo archive, new `kanban.png`.
- **2026-10-28:** **1.1.0-beta, open work** (ADR-0074), on the `feat/lavoro` branch: open questions, risks, requests; owner, due dates, waiting, priorities, dependencies, recurrences, checklists; Track and Manage modes; To do, Overview with status report, Kanban with free columns and 14-day archive; morning notification; suggestions of all types from the engine and from Claude; MCP tools; exports and graph. Migration `v21-work` (additions only), tested on a copy of a real archive. Site header with the fixed Usage/Technical switch, wide search and app version.
- **2026-10-28:** design of open work (ADR-0074 proposed, [`docs/design/lavoro-aperto.md`](design/lavoro-aperto.md)), on the `feat/lavoro` branch: no code until it is approved.
- **2026-10-28:** version 1.0.1-beta and restore point (tag `v1.0.1-beta`, `release/1.0.x` branch); version rule in `CLAUDE.md` and README-collaborators; README › Going back to a previous version.
- **2026-10-27:** recognizing the same voices in different calls (ADR-0073): Settings › Voices, off by default. Giving a speaker a name teaches its voice; in later calls the suggestion "Speaker 2 becomes Marco" arrives with "Recognized by voice (similarity …%)", always to be confirmed. Voiceprints encrypted with the call's key, never to Claude or in exports; voices can be deleted one by one or all together (three steps). Migration `v20-voices`.
- **2026-10-27:** fixes after the code review: a chat cancelled while waiting in the queue exits immediately; searching while typing does not interrupt background work; Claude's points "from the screenshot" require a real screenshot at that minute; the automatic summary does not overwrite a summary by Claude or edited by hand that arrived in the meantime; undoing a Claude summary rewritten afterwards is refused; screenshots without duplicates after a crash and without leftover text after deletion; screenshot minute taken at the request; shortcuts always with ⌃ or ⌥; `release.sh` cannot package an old build.
- **2026-10-27:** Claude makes summaries and suggestions instead of the engine (ADR-0071): "Copy for Claude" in the item card, MCP tools `recent_items`, `summary_template`, `set_summary`, `propose_suggestions` with the quotes verified by IAGO, undoable. "Mark moment with screenshot" and shortcuts in all apps ⌃⌥M, ⌃⌥S, ⌃⌥R (ADR-0072): screenshots encrypted in the call, text read with the Mac's OCR in the transcript, the search and the summaries; images to Claude only if the user chooses so; new Screen Recording permission. Distribution with DMG; copies built from source do not look for updates (amendment of ADR-0059).
- **2026-10-27:** single engine queue (ADR-0069): transcription, engine and search one at a time, chat interrupts background work, MLX memory limits and pause under memory pressure; below 32 GB automatic suggestions and summaries off by default (new "Automatic summaries" switch) and model released at the end of the work; Gemma 4 12B not usable below 24 GB. Provenance of results (ADR-0070): every summary, suggestion and confirmed key point says which model produced it or whether Claude did, with "small model" below 9B (migration `v18-provenance`).
- **2026-10-27:** JSON importable (dragged, from file or pasted), shown in order; CSV, XML, YAML and other text files importable. IAGO, Edit and Window menus: ⌘C, ⌘V, ⌘X, ⌘A, ⌘Z, ⌘W and ⌘, work in text fields and windows (before, only right-click). Hard limit per request to the engine: a huge line (a compact JSON) no longer saturates memory.
- **2026-10-25:** no personal email address in the repository (amendment of ADR-0065). The history was rewritten with the anonymous GitHub addresses and `giovannilombi/iago` recreated, because closed PRs kept the old commits: PRs #1 and #2 no longer exist (their content is in `main`), the issues were transferred. Checks in `pre-commit`, `commit-msg`, new `pre-push` and new `privacy.yml` workflow on GitHub. Link to the documentation site at the top of the README.
- **2026-10-24:** VitePress documentation site on two levels, Usage and Technical (ADR-0068), ready locally; online when the repository becomes public. Documentation required with every commit (commit check). Fixed the guide and the tour about clicking the icon (click opens the menu, right-click starts and pauses, ADR-0026) and `docs/installazione.md` (updates, echo). Fixed the CI hang on the IAGOIngest tests (HTML without WebKit, time limits).
- **2026-10-24:** clean repository and 1.0.0-beta (ADR-0065); automatic checks on commits (no real data, no AI co-author, team co-authors); starter example in a new archive and streams that can be pinned (ADR-0066); ADR-0067 on MiniCPM; documents for collaborating.
- **2026-10-21:** listening bar; context in "Ask IAGO" with "Widen context"; removed the icon next to the category; macOS echo cancellation withdrawn (ADR-0053) and echo cleanup after recording rejected (ADR-0064).

## How to restart with a clean session
1. Read [`CLAUDE.md`](../../CLAUDE.en.md), this file and [`README-collaborators.md`](../../README-collaborators.en.md).
2. `git status`, `git log --oneline -5`, `gh pr list`: work on a new branch from an up-to-date `main`.
3. Before working on an area, read the related ADRs (index in [`docs/adr/README.md`](adr/README.md)).
