# ADR-0050 — Watched folders for emails

- Status: accepted
- Date: 2026-10-19
- Spec references: sec. 7.x (email import, FR-180…184), ADR-0040 (email parser); user request 2026-10-19

## Context
Emails enter IAGO only if the user drags or imports them. Capturing them directly from Outlook would require IT or the network (Microsoft Graph, add-ins), or fragile reading of the Outlook cache. The user can, however, create on their own a **Power Automate** rule that saves emails as `.eml` into a OneDrive folder synced to the Mac. IAGO needs to:
- watch that folder;
- import only what is new, incrementally;
- discard on its own what is not needed, such as meeting invitations;
- assign the project in bulk, with as few confirmations as possible.

## Decision
- **Watched folders** (Settings › Email and people):
  - one or more folders, with their subfolders;
  - `.eml` and `.emlx` files;
  - IAGO checks them when they change and in any case every minute, because OneDrive does not always report new files.
  - For each folder: active or paused, and "Move imported ones to the «Importate» subfolder", off by default.
  - No network: IAGO reads local files. Power Automate belongs to the user and runs on their account.
- **Delta:**
  - a register (`watched_file`, migration `v15-watched-folders`) keeps path, size, modification date, SHA-256, outcome, and the item created;
  - a file already seen and not changed is not reopened;
  - the same content at another path is a duplicate;
  - the same email (same Message-ID) already in the archive is a duplicate, as today;
  - the outcome of each file is one of **imported**, **duplicate**, **discarded** (with the reason), and **failed** (with the error).
- **Rules:**
  - **built-in, on:**
    - meeting invitations and responses: `text/calendar` content, or subjects "Accettato:", "Rifiutato:", "Provvisorio:", "Annullato:", "Invito:", "Accepted:", "Declined:", "Tentative:", "Canceled:", "Invitation:";
    - automatic replies: `Auto-Submitted`, `X-Autoreply` header, or subjects "Risposta automatica", "Automatic reply", "Fuori sede", "Out of office";
  - **built-in, off:** newsletters, recognized by the `List-Unsubscribe` header or by `Precedence: bulk/list`;
  - **user rules**, in order:
    - "**Exclude** if sender / domain / recipient / subject contains…";
    - "**Assign to** project (and stream) if sender / domain / recipient / subject contains…".
  - **Order of application:** first exclusions, then assignments. Without an assigning rule, the suggestion IAGO already makes for emails applies: thread, addresses already seen, sender's project. If the suggestion is not certain, the email goes into "Unfiled".
- **In bulk:**
  - no window for each single email;
  - at the end, a summary notification: "Imported 12 emails (3 discarded, 2 duplicates)";
  - attachments follow today's choice: all except images under 20 KB, that is signatures and logos;
  - the **"Discarded"** list allows **"Import anyway"**.
- **The rules live in IAGOIngest** as a pure function, tested without an archive. Saved rules and the file register live in IAGOStore (`import_rule`, `watched_folder`, `watched_file`).

## Consequences
- With a Power Automate rule, incoming and outgoing emails reach IAGO without IT and without opening the network.
- The rules also serve to discard noise. Discarded files stay visible and recoverable.
- A format other than `.eml`/`.emlx`, for example Outlook for Windows' `.msg`, is not supported: Power Automate saves as `.eml`.
