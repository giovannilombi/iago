# ADR-0010 — Accesso Claude per progetto, MCP stdio, registro accessi

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: sez. 3.14, 12, 17.10

## Contesto
L'utente vuole interrogare l'archivio da Claude Desktop con il proprio abbonamento. Ciò che Claude legge viene inviato ai server di Anthropic: è un'uscita di dati dal Mac.

## Decisione
- Eseguibile `iago-mcp` nel bundle, trasporto solo stdio, nessuna porta di rete, DB in sola lettura.
- Flag "Consultabile da Claude" per progetto, default spento. Le righe senza progetto non sono mai consultabili.
- Ogni chiamata registrata in `audit_log`, visibile all'utente.
- Avviso esplicito nelle impostazioni sull'invio dei contenuti ad Anthropic.

## Conseguenze
- Consenso granulare e tracciato.
- `iago-mcp` deve accedere alla master key tramite access group del Portachiavi: da verificare con il Personal Team gratuito (fase 3).
