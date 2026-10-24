# ADR-0009 — Tag ed entità automatici solo come suggerimenti

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: sez. 3.11 (FR-103), 3.12 (FR-111), 17.9

## Contesto
L'estrazione con LLM locale (fase 3) produce errori e duplicati. Applicarla direttamente sporcherebbe tag ed entità, che sono la base di filtri, collegamenti ed export.

## Decisione
Tutto ciò che è proposto automaticamente (tag, entità, progetto, categoria) finisce nella tabella `suggestion` e va accettato, modificato, unito o rifiutato dall'utente. Mai applicazione automatica.

## Conseguenze
- Serve una UI di revisione efficiente (fase 3).
- I dati classificati restano affidabili; le entità supportano alias per i merge.
