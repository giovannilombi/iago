# ADR-0061 — Built-in guide, welcome tour and demo archive

- Status: accepted
- Date: 2026-10-21
- References: "pre-distribution" memory; CLAUDE.md › Rules; user requests 2026-10-21

## Context
The app must be usable by others without assistance. A complete, always up-to-date guide is needed, with images that do not show real data.

## Decision
- **The guide:**
  - Markdown chapters in `App/Resources/Guide/NN-nome.md`, with images in `Guide/img`, included in the bundle as a folder;
  - the **IAGO Guide** window shows them full page, with table of contents, search and "previous/next";
  - it opens from **? Guide** (top left, next to Settings), from the IAGO icon menu and from Settings › Help;
  - the `{{icona}}` placeholder shows the real menu bar icon in the text.
- **The welcome tour:**
  - 7 screens: work memory, recording, importing, decisions and moments, summaries, Ask, data under your control;
  - at launch until the user chooses "Don't show again";
  - it can be viewed again from the guide and from Settings › Help.
- **Wording:** we say "IAGO icon", and the first time "our parrot with an iron memory". The central concept is the queryable memory (ADR-0058).
- **Demo archive**, only in the Debug build:
  - `-IAGODemoRoot <folder>` opens a separate archive and fills it with made-up data;
  - `-IAGODemoTour <folder>` takes the window through the guide's screens and waits for each screenshot (`screencapture -l`).
- **Rule:** the guide is updated with every change visible to the user, together with README and `docs/prove-tester.md`.

## Consequences
- Guide and README share the chapters: the README lists them with a link.
- Every new important screen is added to the demo tour.
