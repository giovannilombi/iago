# ADR-0020 — Nessun accesso automatico alle caselle email

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: v1.4 sez. 3.19, 17.I; addendum G.I, H.20

## Contesto
Collegarsi direttamente a una casella (IMAP, Exchange, Gmail) renderebbe l'import automatico, ma porterebbe in IAGO grandi quantità di dati non scelti e richiederebbe credenziali e rete.

## Decisione
Nessun accesso diretto alle caselle email. Ogni email entra solo per azione esplicita dell'utente: testo incollato, file `.eml` o trascinamento da Mail/Outlook, screenshot, e in fase 3 menu Condividi/Servizi.

## Conseguenze
- Nessuna credenziale email e nessuna chiamata di rete aggiuntiva.
- L'utente decide cosa entra nella memoria del progetto.
