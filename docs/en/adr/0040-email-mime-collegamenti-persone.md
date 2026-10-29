# ADR-0040 — Email: local MIME parser, conversations, links, and people

- Status: accepted
- Date: 2026-10-13
- Spec references: FR-180…185, FR-200…203, sec. 8.4.2; user request (dragging from Outlook, client's people)

## Context
Emails arrive as `.eml` (also dragged from Outlook or Mail as "promised" files), as pasted text, or as screenshots. MIME parsing, conversations, attachments as linked documents, and recognition of people to suggest the project are needed. No external service, no network.

## Decision
- **Own MIME parser** (`IAGOIngest/EmailParser.swift`), instead of a library:
  - covers headers with continuations, RFC 2047 encoded words, RFC 2231 parameters, nested multipart, base64, quoted-printable, charsets via IANA, inline `message/rfc822`, RFC 5322 dates;
  - no extra dependency to verify and maintain.
- **HTML → Markdown with an own converter**, not with `NSAttributedString`/WebKit, which could load remote images (tracking pixels). Scripts, styles, and images are discarded; headings, paragraphs, lists, links, bold, and quotes remain. If there is a `text/plain` body, it is used.
- **Archive (migration `v9-email`):**
  - `email_meta` as in the spec, with addresses in JSON and `thread_id`;
  - `item_link` as in the spec;
  - a new `contact` table (person = `entity`, email, role internal/client/supplier, client or project; both null = the user's colleagues).
  - The contacts' people are the same entities suggested on decisions.
- **Conversations:** an email joins the conversation of the message it replies to (`In-Reply-To`, then `References`) and is linked with `reply_to`. Replies already in the archive are re-attached even if the original message arrives later.
- **Direction:** it is "sent" if the sender is among the user's addresses (Settings › Email and people), otherwise "received". It can always be changed.
- **Attachments:**
  - they become linked documents with `attachment_of`, in the same project as the email;
  - all are preselected except images under 20 KB (signatures and logos);
  - the original `.eml` is kept encrypted.
- **Known domains** (user request): a rule per domain applies across the whole app and extends to subdomains. It is saved in the `email_domain_rules` setting.
  - For example `@azienda.it` → internal, or `@fornitore.it` → supplier.
  - A domain with the client role can be tied to a client: it is added from the client's "People…" window, and makes its projects suggested.
  - A person added by name counts more than the domain.
  - Next to each email address, the label Internal / Client / Supplier appears.
- **Suggested project:** the senders and recipients that are contacts of a client or a project are considered (colleagues do not count). If the client has only one project, that one is suggested.
- **Dragging from Outlook and Mail:** the window accepts files, `public.email-message`, and data. An element that is not a file is read with `loadFileRepresentation` and copied into the temporary folder. The offered types are written to the log (without content), so an unrecognized drag can be diagnosed. Text-only drags are ignored.

## Consequences
- Outlook for Windows' `.msg` format is not supported: from Outlook for Mac, dragging produces `.eml`.
- Automatic suggestion of links via LLM arrives in Phase 3, always to be confirmed.
