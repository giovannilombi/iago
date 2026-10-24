# Panoramica tecnica

Questa sezione è per chi lavora su IAGO o vuole capire come è costruito: architettura, dati, pipeline, modelli, scelte e motivi. Per come si **usa** l'app, passa al livello **Uso** con il selettore in alto.

## IAGO in dieci righe
- App **nativa macOS** (Swift 6, SwiftUI con AppKit dove serve), in barra dei menu, **non in sandbox** e con *hardened runtime*, per poter registrare l'audio delle altre app.
- **Dieci pacchetti Swift** con un grafo di dipendenze fisso; il target dell'app è l'unico che importa SwiftUI e MLX.
- **Archivio locale:** SQLite (GRDB) con 17 migrazioni, file cifrati a blocchi con una chiave per elemento nel Portachiavi.
- **Cattura** su due tracce (sistema con un *process tap* di Core Audio, microfono con un IOProc HAL) sullo stesso orologio di sistema.
- **Trascrizione locale:** whisper.cpp (predefinito) o Parakeet su CoreML, VAD e diarizzazione con FluidAudio.
- **Comprensione locale:** motore MLX dentro l'app (Qwen 3.5 4B/9B, Gemma 4 12B), embedding Qwen3 0.6B, ricerca ibrida FTS5 + vettori.
- **Niente scritture silenziose:** il motore propone, l'utente conferma; ogni punto di sintesi deve citare la trascrizione.
- **Claude facoltativo** via MCP stdio, con scritture solo dopo anteprima e conferma.
- **Rete:** quattro uscite ammesse, esplicite e registrate; uno script in CI blocca le altre. Nessuna telemetria.
- **Distribuzione** senza App Store né notarizzazione, aggiornamenti firmati con Sparkle da GitHub Releases.

## Dove trovare cosa
| Argomento | Pagina | ADR principali |
|---|---|---|
| Pacchetti, flusso dei dati, coda dei lavori | [Architettura](./architettura) | 0001, 0055 |
| Database, cifratura, migrazioni, backup | [Dati e archivio](./dati) | 0007, 0008, 0027, 0028, 0030, 0041 |
| Registrazione, microfono, riunioni | [Cattura e riunioni](./cattura) | 0002, 0003, 0004, 0025, 0051 |
| Whisper, Parakeet, diarizzazione, eco | [Trascrizione](./trascrizione) | 0005, 0006, 0023, 0062 |
| Email, documenti, OCR, cartelle sorvegliate | [Importazione](./importazione) | 0019, 0020, 0033, 0040, 0050 |
| Ricerca, punti chiave, proposte, sintesi, Chiedi | [Intelligenza](./intelligenza) | 0036, 0046, 0049, 0052, 0054 |
| Modelli locali, catalogo, scelta | [Motore locale](./motore) | 0048, 0067 |
| Server MCP, strumenti, scritture | [Claude e MCP](./claude-mcp) | 0010, 0043, 0044, 0047 |
| Rete, registro accessi, principio sui dati | [Privacy e rete](./privacy-rete) | 0058 |
| Sparkle, release, notarizzazione | [Distribuzione e aggiornamenti](./distribuzione) | 0056, 0059, 0060, 0065 |
| Setup, comandi, CI, regole del team | [Sviluppo](./sviluppo) | 0065, 0068 |
| Tutte le decisioni | [Decisioni (ADR)](/adr/) | — |
| Misure e prove | [Qualità e misure](./qualita) | — |

Lo stato del progetto e le cose aperte sono in [Stato e roadmap](/stato).
