# ADR-0081 — Getting-started introduction

- Status: accepted (1.2.9-beta)
- Date: 2026-10-30
- References: ADR-0066 (the app contains no content), ADR-0068 (guide and site), ADR-0077 (Italian and English); user request of 2026-10-15, taken up again on 2026-10-30

## Context
- Before distributing IAGO it needs an introduction that teaches how to use it, beyond the first-launch setup.
- The welcome tour had seven text-only cards: it did not show the app, let the user try nothing and did not mention importing, the project's views and Claude.

## Decision
- **Introduction** instead of the tour, with the line *«IAGO, always on your shoulder. Meeting after meeting.»*: ten mandatory steps, each with the app's real screenshot and a button that takes the user to that place:
  1. the memory of work; 2. recognized meetings, recording and the panel after Stop; 3. importing; 4. transcript, names and summary; 5. Overview, Timeline, Kanban and Graph; 6. the Inbox; 7. decisions and tasks with their source; 8. Ask IAGO; 9. Claude on the chosen projects; 10. data and choices.
- **First steps**, on the side: record a call, import an email or a document, name a speaker, put an item in a project, confirm a suggestion, ask a question. They tick themselves by reading the archive (`Archive.firstSteps`); connecting Claude is optional and does not count.
- It appears after the first-launch setup and at every launch, until the user chooses *Don't show again* or completes the first steps. It is reopened from Help (Getting started chapter) and from Settings › Help.
- The screenshots are the guide's, retaken by the demo tour in Italian and English: updating the guide updates the introduction too. The tour adds *grafo*, *dopo-stop* and *claude*.
- «Open the example project» opens the main project of the example projects (ADR-0066, change of 2026-10-31), the same as in the screenshots.

## Consequences
- It is kept up to date until distribution, together with the guide (`docs/stato.md`).
