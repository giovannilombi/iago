# ADR-0098 — Collect mode: an archive to query, without management

- Status: accepted
- Date: 2026-11-07
- Changes: ADR-0074 and ADR-0076 (Track and Manage modes), ADR-0087 (Inbox)
- References: ADR-0054 (summaries), ADR-0069 (the Mac's memory), ADR-0072 (bookmarks with screenshots); user request of 2026-11-07, approved on a preview

## Context
- Some projects are only a collection of materials to search and query, Claude included: interviews, focus groups, tender archives, research. They hold audio, PDFs, emails and documents with their transcripts and texts.
- For these projects the management side is noise: key points, Overview, Kanban, Graph and open work in the Inbox. Even *Track mode*, the simplest, has it.

## Decision
- **A third mode, the simplest: Collect mode** (`WorkMode.collect`). It is chosen like the others: from the pill next to the project name, from the icon in the sidebar, in Settings › Projects or for a client's new projects. Icon: an orange archive box. In the choice window it comes first: Collect, Track, Manage.
- **What stays:**
  - the *Items* and *Timeline* views, with the filters;
  - transcripts, extracted texts, summaries;
  - **bookmarks and screenshots**, in their section and in the transcript;
  - **suggestions** of speaker names, tags, project and links;
  - search, *Ask IAGO* (as it is today) and Claude;
  - tags, categories, people and voices.
- **What is not there:**
  - **views:** Overview, Kanban, Graph and the *Show* menu; the timeline shows only the items;
  - **key points:** not in the *Add* menu, not in the item card, not next to bookmarks (*Becomes a decision…*);
  - **key-point suggestions:** the engine does not look for them and the card does not show them (`SuggestionEngine.Input.keyPoints`). Claude cannot write them: the tool says so and explains how to change mode.
- **Inbox:**
  - the open work of projects in Collect is not there;
  - their **suggestions** are (names, tags, project, links), because they are small confirmations not to be lost (`Archive.pendingInboxSuggestions`);
  - a discreet line explains it: «From projects in Collect mode only the suggestions to confirm arrive here».
- **Summaries:** on a Mac with **16 GB or less**, automatic summaries skip projects in Collect (`IntelligenceService.summarizesByItself`): they are made with *Generate summary* or with Claude. An archive can hold many recordings, and every summary takes the Mac for minutes. Above 16 GB the settings apply.
- **No data is lost:**
  - key points written before stay saved and become visible again when switching to Track or Manage;
  - they also stay visible in *Key points* and in everyone's Kanban, which show every project;
  - the mode is already text in the project, so no migration is needed.

## Consequences
- An archive project is read and queried without management tools, and on a small Mac it does not weigh it down.
- **Going back:** an earlier version of IAGO cannot read a project in Collect. Before going back, projects must be put back into Track or Manage; the backup made before updating remains the safe way (README › Going back to a previous version).
- Guide, tour and screenshots present three modes.
