# ADR-0066 — Starter example in a new archive

- Status: accepted
- Date: 2026-10-24
- References: ADR-0038 (client › project › stream), ADR-0063 (sidebar), ADR-0065 (no real data)

## Context
- The distributed app must not contain any content: everything the user creates stays theirs, on their Mac.
- An empty sidebar, however, does not show how work is organized (client, projects, streams, "Pinned").

## Decision
- In a **new and empty** archive (no client, project or item; initial setup not yet done), at first launch IAGO creates:
  - the client **Test Client**;
  - the projects **Test Pj. 1** and **Test Pj. 2**;
  - in Test Pj. 1 the streams **Pj1 - Stream 1** and **Pj1 - Stream 2**;
  - pinned: **Pj1 - Stream 1** and **Test Pj. 2**.
- Structure only: no item, note or audio.
- It is created **only once** (setting `starter_example_done`): if the user deletes it, it does not come back; it is never created on an archive already in use.
- **Streams** can also be pinned in "Pinned" (right-click › Pin to top), like projects, categories and tags.
- The name of the second stream follows the user's request ("PJ2 - Stream 2" read as the second stream of Test Pj. 1, hence "Pj1 - Stream 2").

## Rejected alternatives
- **No example:** cleaner, but those starting out do not see the structure. The guide and the tour explain it, but the example shows it.
- **A demo archive with content** (like the one for screenshots): too much fake data to delete in a work archive.

## Consequences
- Those who do not want the example delete it with one click on the client; those who do, rename it and use it.
- The demo archive with made-up content (ADR-0061) remains only in the Debug build, for screenshots: it is not in the distributed app.

## Change of 2026-10-31 (1.2.10-beta)
User request: a freshly opened app must have example projects with content, to show right away how to work.
- A new archive receives, only once and after the language is chosen, the **example projects** of an invented digital agency: **Poldo S.p.A.** (Headless customer portal with the UX/UI and Development streams, Design system), **Sanna TheBest s.r.l.** (Rebranding), **Atoms** (Product discovery) and an internal project. Inside there are transcribed calls with summaries, emails, documents, decisions with their history, tasks, risks, open questions, requests, notes, those present and suggestions to confirm, about UX, UI, product design, branding and headless development.
- Everything is invented, in the app's language, dated around the day of creation, without audio. The same content feeds the demo tour: guide, introduction and app show the same example.
- The example's items are marked (`capture_meta = example`) and do not count in the introduction's first steps (ADR-0081).
- **Settings › Projects › Remove the example** deletes the example's clients, projects and content; what the user moved elsewhere stays. It does not come back.
- It supersedes the «A demo archive with content» option discarded above: removal with one click solves the problem of fake data to delete. Archives created earlier keep the old «Test Client» structure.
