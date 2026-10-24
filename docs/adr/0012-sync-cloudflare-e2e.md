# ADR-0012 — Sync futura E2E su Cloudflare, nessun servizio esterno prima

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: sez. 3.15, 13, 17.12

## Contesto
La condivisione di progetti tra utenti e l'accesso da web/mobile richiedono un backend. Il backend non deve poter leggere i contenuti.

## Decisione
- Fase 4: Cloudflare Workers (API), D1 (metadati cifrati, change feed), R2 (blob cifrati), cifratura end-to-end (chiave di progetto cifrata per ogni membro con X25519).
- Fasi 0–3: nessun servizio esterno. Esistono solo i campi di sync nel modello, il `change_log`, i flag `shared`/`sharing_enabled` e le interfacce vuote in `IAGOSync`.

## Conseguenze
- Il server vede solo dati cifrati, ID e timestamp; ricerca sempre lato client.
- L'account Cloudflare si crea solo in fase 4 (piano gratuito, compatibilmente con il vincolo "nessun servizio a pagamento").
