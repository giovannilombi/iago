# ADR-0078 — IAGO's and Teams' transcripts side by side, Claude suggested on slow Macs

- Status: accepted (1.2.5-beta)
- Date: 2026-10-30
- References: ADR-0033 (Teams transcripts), ADR-0043 (MCP server), ADR-0054 (summaries), ADR-0069 (single queue and memory), ADR-0071 (summaries and suggestions made by Claude), ADR-0058 (nothing leaves without the user's choice); user requests of 2026-10-30

## Context
- Attaching the Teams transcript **replaced** IAGO's, with two losses:
  - Teams' minutes count from the start of the Teams transcription, not of the recording, so the links to the audio led to the wrong point;
  - IAGO's transcript, with its two tracks and the voices, was gone.
- The user wants both, side by side, always by their choice, with the option to delete one or the other later.
- On Macs up to 16 GB, summaries and suggestions with the local engine are slow. Claude can do them with the same checks (ADR-0071), but the user does not find out unless something tells them.
- Transcribing with Claude is ruled out: Claude models do not read audio.

## Decision
- **Two transcripts side by side:**
  - a call can have IAGO's transcript and Teams' together. The main one is the `transcript_json` asset, the other `alternate_transcript_json`. No migration: asset kinds are text;
  - *Attach Teams transcript…* **adds**: if the call has IAGO's transcript, that stays the main one and Teams' sits beside it. Another Teams transcript replaces only the Teams one;
  - *Transcribe* on a call that has only Teams' moves Teams' aside and puts IAGO's in front, since its minutes are tied to the audio;
  - the item card has the tabs **IAGO**, **Teams** and Markdown. Teams' minutes are plain text (`Transcript.isImported`): no link to the audio, no «Listen from here», no screenshots at their minute. The same goes for summaries, key points and search results of a call whose main transcript is Teams';
  - **there is one main transcript**: summaries, suggestions, search, exports and Claude read that one, so no sentence counts twice. *Use this one for summaries, suggestions and search* swaps them (`Archive.swapTranscripts`): both are written again to their own file, so a new transcription never overwrites the other one. A summary already written does not change by itself;
  - *Delete this transcript…* removes one of the two, for good, after confirmation. The other stays and becomes the main one. Its speakers go with it and, for Teams, the original file (`Archive.removeTranscript`);
  - the names of Teams' speakers stay as Teams writes them. Matching them to IAGO's speakers needs the times of the two transcripts aligned: a later step, not in this ADR.
- **«Use Claude» tip:**
  - on Macs up to 16 GB, under *Summary* and *Suggestions*, a box suggests Claude: *Ask Claude for the summary* copies the request of ADR-0071 and opens the Claude app, and the user pastes it. IAGO cannot hand a job to Claude by itself, because with MCP it is always Claude that calls IAGO;
  - **nothing is enabled by itself.** The box says what is missing and offers the step, always with a click from the user:
    - no connection to IAGO in Claude Desktop's configuration: *Connect Claude…* opens Settings › Claude;
    - connections limited to other projects (`--project`, `--client`): a connection that includes this one must be added;
    - project Claude cannot read or write: *Allow and ask Claude* enables it for that project only;
    - item without a project: it must be assigned first, because Claude writes only in projects;
  - every result goes through the preview and the user's OK, as always (ADR-0047). «It appears here» means that after the OK the summary is in the item card;
  - *Use the Mac's engine* hides the tip on that project for good (archive setting `claudeTip.declinedProjects`); *Don't show again* hides it on that Mac;
  - **Settings › Engine › Summaries and suggestions: Mac's engine / Claude** (`intelligence.byClaude`). With Claude the Mac's engine no longer starts by itself, the automatic jobs are off and the tip appears on any Mac.
- Claude Code's connections are not read: IAGO has no reliable file to find them in. Someone who uses only Claude Code sees «Connect Claude…», but can still copy the request from *Copy for Claude…*.

## Consequences
- Search and exports contain only the main transcript. To search in the other one, make it the main one.
- Earlier calls with Teams instead of IAGO are recognized from the engine of the saved transcript (`asr = teams`): their minutes stop being links to the audio.
- The tip prepares the ground for other assistants (ADR-0079): today it names Claude, tomorrow the chosen assistant.
