# ADR-0077 — Italian and English, always aligned

- Status: accepted (1.2.2-beta)
- Date: 2026-10-29
- References: ADR-0054 (summaries by category), ADR-0061 (built-in guide), ADR-0066 (starter example), ADR-0068 (site and documentation with every commit); user request of 2026-10-29

## Context
- IAGO was only in Italian: interface, guide, site, development documents and texts written by the engine (summaries, suggestions, answers). The String Catalog was set up, but almost empty.
- The user wants the app and all the documentation in Italian and English, with the language chosen at first launch and easy to change, and both languages maintained with every change.

## Decision
- **Italian remains the source language**, English follows it. Every new or changed text is written in both languages in the same commit.
- **App:**
  - strings are extracted into the String Catalog (`SWIFT_EMIT_LOC_STRINGS`) and translated into English;
  - **the language is chosen at first launch**, as the first step, with the two names each written in its own language;
  - **it is changed in Settings › General › Language**. macOS applies the language at launch (the app's `AppleLanguages`), so IAGO asks to restart;
  - the built-in guide has one folder per language: `App/Resources/Guide` (Italian) and `App/Resources/Guide/en`, with its own screenshots.
- **What IAGO writes follows the app's language:** summaries, suggestions, status reports, answers of "Ask IAGO", new tags.
  - The instructions to the engine stay in Italian and say which language to write in (`ContentLanguage` in IAGOCore, saved in `UserDefaults` by the app).
  - The summary templates have an English version with the same ids and the same sections (`SummaryLibrary.englishLibrary`).
  - Quotes stay as they were spoken.
- **Names given by IAGO:** the starter example and the default categories with an Italian name (SAL, Interna, Altro) take the name in the app's language when the language changes, if the user has not renamed them (`Archive.relabelDefaults`). Category families stay saved with the Italian name and are shown translated.
- **"Me":** your own voice without a name is called "Io" in Italian and "Me" in English; both always refer to the user.
- **Documentation:** every document has its English version:
  - `docs/x.md` → `docs/en/x.md`;
  - `README.md`, `README-collaborators.md` and `CLAUDE.md` → `*.en.md`;
  - the guide → `App/Resources/Guide/en/`.

  The VitePress site has Italian at the root and English under `/en/`, with the language switcher.
- **Glossary:** `i18n/glossary.tsv` fixes the English names of the interface and the concepts, for the app and for the documents.
- **Alignment checked automatically:** `scripts/i18n.py check` runs in the `pre-commit` hook and in CI. It blocks if:
  - an Italian document has no translation;
  - an Italian document changed after its translation;
  - a catalog string has no English;
  - a string in the code is not yet in the catalog.

  `i18n/sources.json` records which Italian text each English file comes from.
- **The translation is written by whoever makes the change**, in practice Claude Code during the work, before the commit: no online or paid translation services (ADR-0058).

## Consequences
- The work on every change includes the translation. `scripts/i18n.py missing` and `apply` go through Xcode for the app strings; `record` registers the translated documents.
- Dates in transcripts ("entro venerdì") and generated speaker names ("Speaker 1", "Stanza") are still recognized in Italian: they are call data, not interface.
- The MCP tools for Claude stay described in Italian: Claude understands them in both languages.
- The first translation of everything (about 1,700 strings and 70,000 words of documents) was done with 1.2.2-beta.
