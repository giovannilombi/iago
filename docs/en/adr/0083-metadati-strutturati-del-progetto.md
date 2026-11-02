# ADR-0083 — Structured project metadata

- Status: accepted (principle for phase 4; no code yet)
- Date: 2026-11-02
- References: ADR-0058 (nothing leaves the Mac unless the user wants it to), ADR-0073 (voice prints), ADR-0082 (sync for every client); internal review board of 2026-11-02

## Context
- IAGO aims to be the team's shared brain: finding information without wasting time looking for it. It does **not** replace Salesforce, the ERP or time tracking, and won't go in that direction.
- The data that describes the work on a project already exists, spread across items: type, date, duration, project, client, category, tags, attendees, origin.
- Today no format gathers it per project, and with sharing whoever inherits a project (a manager, for example) needs to find it complete and readable.

## Decision
- **Every item has a fixed set of metadata, with no content:**
  - type (call, email, document), title, date, duration;
  - project, stream, client, category, tags;
  - attendees and named speakers (names only);
  - origin (IAGO recording, Teams transcript, email, imported document) and status;
  - how many key points came from it, by type.
- **The project carries the register of its metadata**, attached to the project: a readable list of its items with these fields, which travels with the project when it is shared, in the neutral format of ADR-0082.
- **No content:** no transcripts, text, audio or notes in the register, and never voice prints (ADR-0073). Content stays in the item and follows its own sharing rules.
- Field names and their format are fixed in the technical documentation together with the sync format, before the code.

## Consequences
- Whoever receives a shared project sees at once what happened and when, even without opening the content.
- A future count (call hours per project, for example) can be done on the register without touching the content. It is not a goal of this decision.
- Attendees are personal data: they enter the register only if the project is shared, under the same rules as the rest of the project.
