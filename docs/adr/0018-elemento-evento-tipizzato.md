# ADR-0018 — L'elemento è un evento tipizzato nella cronologia del progetto

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: v1.4 sez. 1, 3.19–3.21; addendum A, H.18

## Contesto
Oltre alle call, la storia di un progetto passa da email e documenti. Gestirli in un modello separato duplicherebbe progetto, tag, timeline, ricerca, export, MCP.

## Decisione
`item` ha un campo `type` (`call` | `email` | `document`, default `call`). Tutte le funzioni trasversali (titolo, `occurredAt`, progetto, categoria, tag, note, decisioni, `shared`, timeline, ricerca, export, grafo, MCP) valgono per tutti i tipi. Metadati specifici in `email_meta` e `document_meta`; collegamenti tra elementi in `item_link`. Nella UI il termine è "elemento".

## Conseguenze
- `item.type` è presente dalla prima migrazione della fase 1 (nessuna migrazione successiva).
- `asset.kind` si estende con i tipi di originale e di MD derivato.
- Nuovo modulo `IAGOIngest` per l'estrazione di testo da email e documenti.
