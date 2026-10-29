# ADR-0020 — No automatic access to email mailboxes

- Status: accepted
- Date: 2026-10-11
- Spec references: v1.4 sec. 3.19, 17.I; addendum G.I, H.20

## Context
Connecting directly to a mailbox (IMAP, Exchange, Gmail) would make import automatic, but would bring large amounts of unchosen data into IAGO and would require credentials and network access.

## Decision
No direct access to email mailboxes. Every email enters only through an explicit user action: pasted text, `.eml` file or drag and drop from Mail/Outlook, screenshot, and in phase 3 the Share/Services menu.

## Consequences
- No email credentials and no additional network calls.
- The user decides what enters the project's memory.
