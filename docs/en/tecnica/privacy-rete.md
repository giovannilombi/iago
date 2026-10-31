# Privacy and network

## The principle (ADR-0058)
**Nothing leaves the Mac unless the user wants it to.** There are three levels, all chosen by the user:
1. **On the Mac**, always: encrypted archive, local transcription and engine.
2. **With Claude**, project by project (see [Claude and MCP](./claude-mcp)).
3. **In a shared space** controlled by the user or the company (phase 4, ADR-0057 proposed).

## Allowed connections
The only outbound network connections, all explicit and recorded in the access log:

| # | Connection | When |
|---|---|---|
| 1 | Model downloads from fixed URLs (Hugging Face, pinned commit) with SHA-256 verification | only on user action |
| 2 | Teams local API on `127.0.0.1:8124` | only if the user enables it (ADR-0051) |
| 3 | MCP stdio only | no port: it is not network |
| 4 | Sync | phase 4, to be decided (ADR-0012 / ADR-0057) |
| 5 | Checking for and downloading updates from GitHub Releases (Sparkle, EdDSA signature) | once a day or manually (ADR-0056) |

`scripts/check-network-apis.sh` runs in CI and fails if a network API outside these points appears in the code.

The **screenshots** from *Mark moment with screenshot* stay encrypted on the Mac like recordings. Claude receives their text, like the transcript, for readable projects; the images only if the user enables "Also share screenshot images with Claude" (ADR-0072).

**Voiceprints** (ADR-0073) are biometric data: they are saved only if the user enables Settings › Voices, encrypted with the key of the call they come from, and never go to Claude, exports, Obsidian or sharing. They can be deleted one by one or all together.

## No telemetry
- No analytics, remote crash reporters or telemetry: if a library does any, it must be turned off or replaced.
- System **logs** (`subsystem com.giovannilombi.iago`) do not contain the content of transcripts, documents or notes.

## Content and repository
- The app **contains nobody's content**: a new archive has only the example projects of an invented agency, removed with one click (ADR-0066).
- The repository **never** contains real data: a check before every commit blocks audio, archives, transcripts, emails and the real names listed locally (ADR-0065). Tests and examples use made-up names.
