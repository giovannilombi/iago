# ADR-0008 — UUIDv7, tombstone, versioni e change log da subito

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: sez. 8.1, 13, 17.8

## Contesto
La sync e la condivisione arriveranno in fase 4. Aggiungere identità globali, cancellazioni logiche e un registro modifiche a posteriori richiederebbe migrazioni dolorose.

## Decisione
Ogni tabella utente ha `id` UUIDv7, `created_at`, `updated_at`, `deleted_at` (tombstone), `version`, `device_id`. Ogni mutazione scrive anche su `change_log`. Il contenuto sensibile viene rimosso subito; la riga resta come tombstone finché la sync non lo consente.

## Conseguenze
- Leggero overhead in scrittura e nel codice dei repository, pagato da subito.
- Query sempre filtrate su `deleted_at IS NULL`.
- La fase 4 parte da un modello già compatibile.
