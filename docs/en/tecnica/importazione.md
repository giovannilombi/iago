# Import

Everything that is not a call comes in through `IAGOIngest`, which depends only on `IAGOCore` and works with system frameworks and its own code, on the Mac (ADR-0019, ADR-0033).

## How a file is routed
| Input | What it becomes | How |
|---|---|---|
| Audio, video | item to transcribe (only the audio of a video is kept) | AVFoundation, then the transcription queue |
| Teams transcripts (`.vtt`, `.docx`) | transcript with the speakers' **real names**; attached to a call with IAGO's transcript it sits **beside** it (`alternate_transcript_json`, ADR-0078) and its minutes are not links to the audio (`Transcript.isImported`) | parser for the recent format and the old one |
| PDF | document | PDFKit; OCR for pages without text (`## Pagina N`) |
| Images, screenshots | document | OCR with Vision (`it-IT`, `en-US`, language correction) |
| DOCX, RTF, ODT | document | `NSAttributedString` → Markdown with headings, lists and bold |
| HTML | document | IAGO's own HTML → Markdown converter, without WebKit |
| JSON | document | Markdown code block, **one value per line and indented**, keys in their original order (`ContentExtractor.jsonMarkdown`); this also applies to JSON pasted in *Import › From text* |
| Text, Markdown, CSV, XML, YAML, logs, code | document | read directly (any file type macOS recognizes as text) |
| Emails `.eml`, `.emlx`, `.msg` | email with sender, conversation and attachments | IAGO's own MIME parser (ADR-0040) |

A file IAGO cannot read is rejected with a message ("Unsupported file type"), never silently.

Both **the encrypted original** and **the derived Markdown** are kept; the text can be corrected by hand and the earlier automatic version is kept.

## Emails
- **No access to mailboxes** (ADR-0020): an email comes in only through a user action (drag and drop, file, pasted text, the "Add to IAGO" service) or from a **watched folder**.
- **Own MIME parser:** headers with continuations, RFC 2047 and 2231, nested multipart, base64, quoted-printable, IANA charsets, `message/rfc822`, RFC 5322 dates. No library to vet.
- **HTML → Markdown without a web engine:** scripts, styles and images are discarded, so no tracking pixel is loaded.
- **People and links:** addresses, conversations (`thread_id`), roles by domain (e.g. "@azienda.example → internal"), project suggestions by sender.
- **Import rules:** recognition of invitations, automatic replies and newsletters; user rules to exclude or assign, applied in order.

## Watched folders (ADR-0050)
- One or more folders with their subfolders, `.eml` and `.emlx` files; typically Outlook mail saved by a user's **Power Automate** flow into a OneDrive folder.
- IAGO watches them when they change and in any case every minute, because OneDrive does not always report new files; it imports only new files (delta).
- No network: IAGO reads local files.

## Other inputs
- **macOS "Add to IAGO" service** for text selected in any app.
- **Notes** with attachments: the extracted text goes into the note; for each file IAGO asks whether to keep the original too.
- **Voice notes** transcribed with the same engine as calls (ADR-0021).
