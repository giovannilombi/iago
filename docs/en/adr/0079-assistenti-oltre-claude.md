# ADR-0079 — Assistants beyond Claude: Claude, Claude Code, Gemini, Gemini CLI, ChatGPT, Codex CLI

- Status: proposed (to be analyzed tool by tool before accepting it)
- Date: 2026-10-30
- References: ADR-0043 (stdio-only MCP server), ADR-0044 and ADR-0047 (writes with preview), ADR-0058 (nothing leaves without the user's choice), ADR-0070 (provenance), ADR-0071 (summaries and suggestions made by Claude), ADR-0078 (tip on slow Macs); user request of 2026-10-30

## Context
- Today IAGO talks to a single assistant, Claude: Claude Desktop and Claude Code start IAGO's MCP server (`iago-mcp`) on the Mac and talk to it over stdio, with no network ports (ADR-0043).
- The user wants to be able to use Gemini and ChatGPT too, in their apps and their terminal versions, above all for summaries and suggestions on slow Macs.
- MCP is an open protocol: technically every app that can start a **local** MCP server can use IAGO as Claude does. The apps differ, though, in how they connect, where the data goes and how stable they are.
- IAGO's texts, settings and provenance say «Claude» everywhere.

## Tool-by-tool analysis
State as of 2026-10-30, to be checked again before every step: these apps change often. «Local» means the app starts `iago-mcp` on the Mac (stdio), with no ports.

| Tool | Connection to a local MCP server | Where it is configured | Notes |
|---|---|---|---|
| **Claude Desktop** | yes, already used | `claude_desktop_config.json`, `mcpServers` | full or limited connection (`--project`, `--client`, `--unclassified`) |
| **Claude Code** (CLI) | yes, already used | `claude mcp add` | IAGO already prepares the command |
| **Gemini CLI** | yes, documented (stdio, `command` and `args`) | `~/.gemini/settings.json`, `mcpServers`; `gemini mcp` command | local servers show as connected only in a «trusted» folder; an unofficial source reports access limits for some plans since June 2026, to be verified |
| **Gemini app** (web and desktop) | not documented for local servers | — | Google documents MCP for Gemini Enterprise with cloud-hosted servers, not for the consumer app |
| **Codex CLI** (OpenAI, «ChatGPT in the terminal») | yes, documented (stdio) | `~/.codex/config.toml`, `[mcp_servers.<name>]` tables; `codex mcp add` command | Codex inside the ChatGPT desktop app would read the same file, according to unofficial sources |
| **ChatGPT app** | no for local servers, according to unofficial sources | developer mode and connectors, remote HTTPS servers only | for a server on the Mac OpenAI would offer a «tunnel» client; Business, Enterprise and Edu plans have admin controls |

## Implications to weigh for each tool
1. **Network:** a server reachable over the network (HTTP, tunnel) means an open port or an external service. It goes against ADR-0043 and ADR-0058 and would need its own ADR. Proposal: **only tools that start IAGO locally**.
2. **Where the data goes:** what the assistant reads goes to the company that provides it (Anthropic, Google, OpenAI), according to the user's account and plan, including the rules on training. IAGO must say so for each assistant, in its own words, before the first consent.
3. **Separate consents per assistant:** a project Claude can read does not become readable by Gemini. IAGO needs to know which assistant is calling:
   - each connection carries an `--assistant <id>` argument written by IAGO in the configuration;
   - the name the app declares at startup (MCP's `clientInfo`) is only a check, not a proof: a local app can declare any name.
4. **Provenance (ADR-0070):** «Summarized by Gemini», «Recommended by Codex», with the connection's assistant name.
5. **Quality:** IAGO's checks stay the same for everyone: verified quotes, category template, preview and OK. A less precise assistant produces more dropped points, not saved errors. To be measured with the same test calls for each assistant.
6. **Costs:** IAGO pays nothing and uses no API keys (no paid services). Each assistant uses the user's subscription.
7. **Archive key:** `iago-mcp` receives the key as today, once, through a pipe (ADR-0043), whatever app starts it.
8. **Connection instructions:** for each supported app, in Settings, with the command or configuration block ready to copy, as today for Claude.

## Proposed decision
- **First step:**
  - in IAGO, «Claude» becomes «assistant» in the places shared by all (Settings › Assistants, «Copy for the assistant», the tip of ADR-0078), with the real name where needed;
  - per-project consents separate for each assistant;
  - provenance with the assistant's name;
  - connection instructions for **Claude Desktop, Claude Code, Gemini CLI and Codex CLI**.
- **Then, one test per assistant**, with the test calls (invented names):
  - it connects and works only on the allowed projects;
  - summaries and suggestions pass the checks;
  - how many points are dropped;
  - timings.
- **Gemini app and ChatGPT app:** only when they can start a local MCP server. No tunnels or ports without a new ADR.

## Open questions
- Will the consumer Gemini and ChatGPT apps support local servers? To be checked again at every step.
- Which Gemini CLI plans allow using the terminal app today?
- Do per-assistant consents need a migration (a `project_assistant` table) or are columns on the project enough?
- Does someone using several assistants on the same project want to see who did what in Activity and in the access log too?

## Sources (consulted on 2026-10-30)
- Gemini CLI, MCP servers: [documentation on GitHub](https://github.com/google-gemini/gemini-cli/blob/main/docs/tools/mcp-server.md), [geminicli.com](https://google-gemini.github.io/gemini-cli/docs/tools/mcp-server.html), [Tembo](https://www.tembo.io/blog/gemini-cli-mcp) (reports the access limits, not confirmed).
- Gemini and MCP in Google Cloud: [Devs guide to MCP Apps in Gemini](https://cloud.google.com/blog/topics/developers-practitioners/devs-guide-to-mcp-apps-in-gemini).
- Codex CLI, MCP: [OpenAI developers, Codex MCP](https://developers.openai.com/codex/mcp).
- ChatGPT and MCP (unofficial sources): [coworker.ai](https://coworker.ai/blog/chatgpt-mcp), [mcp.so](https://mcp.so/blog/chatgpt-mcp-setup), [usecarly.com](https://www.usecarly.com/blog/chatgpt-mcp/).

## Consequences
- No change while the ADR stays proposed: today IAGO can be connected only to Claude Desktop and Claude Code.
- Accepting it changes ADR-0071 (Claude) into «assistant», and ADR-0070 in the provenance.
