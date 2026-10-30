# ADR-0080 — Sharing an item

- Status: accepted (1.2.7-beta)
- Date: 2026-10-30
- References: ADR-0058 (nothing leaves without the user's choice), ADR-0073 (voice prints), ADR-0078 (two transcripts); user request of 2026-10-30

## Context
- Sending a call, an email or a document to someone who does not use IAGO meant exporting files one at a time from the *Files* section, or copying text by hand.
- The idea «sending tasks to others» (open work) became broader: sharing the item with what is needed, choosing the parts.

## Decision
- *Share…* among the card's actions opens a list of the parts the item has, with their size, to tick:
  - **Card (Markdown):** date, project, category, duration, participants, tags, summary, key points with their status, notes. No transcript;
  - the main **transcript** with the speakers' names, or the text of emails and documents; the **other transcript** if the call has two;
  - **Audio** (mix or imported file) and **separate tracks** (microphone and system);
  - **Original:** `.eml`, document, image or Teams transcript;
  - **Screenshots**, with the minute in the name.
- IAGO decrypts the parts into a temporary folder (`IAGO-Condividi`, emptied at the next share), optionally in a single `.zip` made with macOS's `ditto`, and then:
  - *Share…* opens macOS's Share menu (Mail, Messages, AirDrop, other apps);
  - *Save to a folder…* copies them where the user chooses.
- **No network call from IAGO:** the files leave only through the app the user chooses.
- Voice prints are not assets and are never among the parts (ADR-0073).
- The window warns that shared files are not encrypted. Every share goes to the access log (`export/share`) and shows in Activity while the files are prepared.

## Consequences
- It replaces the idea «sending tasks to others before phase 4».
- The files' texts (section titles) follow those of the existing exports.
