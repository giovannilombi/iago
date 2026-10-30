# ADR-0079 — Assistenti oltre Claude: Claude, Claude Code, Gemini, Gemini CLI, ChatGPT, Codex CLI

- Stato: proposto (da analizzare strumento per strumento prima di accettarlo)
- Data: 2026-10-30
- Riferimenti: ADR-0043 (server MCP solo stdio), ADR-0044 e ADR-0047 (scritture con anteprima), ADR-0058 (niente esce senza la scelta dell'utente), ADR-0070 (provenienza), ADR-0071 (sintesi e proposte fatte da Claude), ADR-0078 (consiglio sui Mac lenti); richiesta dell'utente del 2026-10-30

## Contesto
- Oggi IAGO parla con un solo assistente, Claude: Claude Desktop e Claude Code avviano il server MCP di IAGO (`iago-mcp`) sul Mac e ci parlano via stdio, senza porte di rete (ADR-0043).
- L'utente vuole poter usare anche Gemini e ChatGPT, nelle loro app e nelle loro versioni da terminale, soprattutto per sintesi e proposte sui Mac lenti.
- MCP è un protocollo aperto: tecnicamente ogni app che sa avviare un server MCP **locale** può usare IAGO come lo usa Claude. Le app però differiscono su come si collegano, dove vanno i dati e quanto sono stabili.
- I testi, le impostazioni e la provenienza di IAGO dicono «Claude» ovunque.

## Analisi strumento per strumento
Stato al 2026-10-30, da riverificare prima di ogni passo: queste app cambiano spesso. «Locale» vuol dire che l'app avvia `iago-mcp` sul Mac (stdio), senza porte.

| Strumento | Collegamento a un server MCP locale | Dove si configura | Note |
|---|---|---|---|
| **Claude Desktop** | sì, già usato | `claude_desktop_config.json`, `mcpServers` | collegamento completo o limitato (`--project`, `--client`, `--unclassified`) |
| **Claude Code** (CLI) | sì, già usato | `claude mcp add` | IAGO prepara già il comando |
| **Gemini CLI** | sì, documentato (stdio, `command` e `args`) | `~/.gemini/settings.json`, `mcpServers`; comando `gemini mcp` | i server locali risultano collegati solo in una cartella «fidata»; una fonte non ufficiale segnala limiti di accesso per alcuni piani dal giugno 2026, da verificare |
| **App Gemini** (web e desktop) | non documentato per i server locali | — | Google documenta MCP per Gemini Enterprise con server ospitati in cloud, non per l'app per tutti |
| **Codex CLI** (OpenAI, «ChatGPT da terminale») | sì, documentato (stdio) | `~/.codex/config.toml`, tabelle `[mcp_servers.<nome>]`; comando `codex mcp add` | Codex dentro l'app desktop di ChatGPT leggerebbe lo stesso file, secondo fonti non ufficiali |
| **App ChatGPT** | no per i server locali, secondo fonti non ufficiali | modalità sviluppatore e connettori, solo server remoti HTTPS | per un server sul Mac OpenAI offrirebbe un client «tunnel»; i piani Business, Enterprise ed Edu hanno controlli dell'amministratore |

## Risvolti da valutare per ogni strumento
1. **Rete:** un server raggiungibile via rete (HTTP, tunnel) significa una porta aperta o un servizio esterno. Va contro ADR-0043 e ADR-0058 e richiederebbe un ADR suo. Proposta: **solo strumenti che avviano IAGO in locale**.
2. **Dove vanno i dati:** quello che l'assistente legge va all'azienda che lo fornisce (Anthropic, Google, OpenAI), secondo l'account e il piano dell'utente, comprese le regole sull'addestramento. IAGO lo deve dire per ogni assistente, nella sua lingua, prima del primo consenso.
3. **Consensi separati per assistente:** un progetto consultabile da Claude non diventa consultabile da Gemini. Serve sapere quale assistente chiama:
   - ogni collegamento porta un argomento `--assistant <id>` scritto da IAGO nella configurazione;
   - il nome che l'app dichiara all'avvio (`clientInfo` di MCP) serve solo a controllo, non come prova: un'app locale può dichiarare qualsiasi nome.
4. **Provenienza (ADR-0070):** «Sintetizzata da Gemini», «Consigliata da Codex», con il nome dell'assistente del collegamento.
5. **Qualità:** i controlli di IAGO restano uguali per tutti: citazioni verificate, modello della categoria, anteprima e OK. Un assistente meno preciso produce più punti scartati, non errori salvati. Da misurare con le stesse call di prova per ogni assistente.
6. **Costi:** IAGO non paga nulla e non usa chiavi API (nessun servizio a pagamento). Ogni assistente usa l'abbonamento dell'utente.
7. **Chiave dell'archivio:** `iago-mcp` riceve la chiave come oggi, una volta, attraverso una pipe (ADR-0043), qualunque sia l'app che lo avvia.
8. **Istruzioni di collegamento:** per ogni app supportata, in Impostazioni, con il comando o il blocco di configurazione pronto da copiare, come oggi per Claude.

## Decisione proposta
- **Primo passo:**
  - in IAGO, «Claude» diventa «assistente» nei punti comuni a tutti (Impostazioni › Assistenti, «Copia per l'assistente», consiglio di ADR-0078), con il nome vero dove serve;
  - consensi per progetto separati per assistente;
  - provenienza con il nome dell'assistente;
  - istruzioni di collegamento per **Claude Desktop, Claude Code, Gemini CLI e Codex CLI**.
- **Dopo, una prova per assistente**, con le call di prova (nomi inventati):
  - si collega e lavora solo sui progetti consentiti;
  - sintesi e proposte passano i controlli;
  - quanti punti vengono scartati;
  - tempi.
- **App Gemini e app ChatGPT:** solo quando sapranno avviare un server MCP locale. Niente tunnel né porte senza un nuovo ADR.

## Domande aperte
- Le app consumer di Gemini e ChatGPT supporteranno i server locali? Da riverificare a ogni passo.
- Quali piani di Gemini CLI permettono oggi l'uso dell'app da terminale?
- Serve una migrazione per i consensi per assistente (una tabella `project_assistant`) o bastano colonne sul progetto?
- Chi usa più assistenti sullo stesso progetto vuole vedere chi ha fatto cosa anche in Attività e nel registro accessi?

## Fonti (consultate il 2026-10-30)
- Gemini CLI, server MCP: [documentazione su GitHub](https://github.com/google-gemini/gemini-cli/blob/main/docs/tools/mcp-server.md), [geminicli.com](https://google-gemini.github.io/gemini-cli/docs/tools/mcp-server.html), [Tembo](https://www.tembo.io/blog/gemini-cli-mcp) (segnala i limiti di accesso, non confermati).
- Gemini e MCP in Google Cloud: [Devs guide to MCP Apps in Gemini](https://cloud.google.com/blog/topics/developers-practitioners/devs-guide-to-mcp-apps-in-gemini).
- Codex CLI, MCP: [OpenAI developers, Codex MCP](https://developers.openai.com/codex/mcp).
- ChatGPT e MCP (fonti non ufficiali): [coworker.ai](https://coworker.ai/blog/chatgpt-mcp), [mcp.so](https://mcp.so/blog/chatgpt-mcp-setup), [usecarly.com](https://www.usecarly.com/blog/chatgpt-mcp/).

## Conseguenze
- Nessun cambiamento finché l'ADR resta proposto: oggi IAGO resta collegabile solo a Claude Desktop e Claude Code.
- Accettarlo cambia ADR-0071 (Claude) in «assistente», e ADR-0070 nella provenienza.
