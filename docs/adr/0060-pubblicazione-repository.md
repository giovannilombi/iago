# ADR-0060 — Pubblicazione del repository

- Stato: accettato (da eseguire quando l'utente dirà di essere pronto a distribuire)
- Data: 2026-10-21
- Riferimenti: ADR-0034 (licenza CC BY-NC-SA), ADR-0056 (feed `giovannilombi/iago`); CLAUDE.md › Regole

## Contesto
- Il repository sarà pubblico, perché gli aggiornamenti si scaricano dalle sue release.
- Nella **storia** dei commit ci sono dati reali delle call dell'utente: nomi di persone e di clienti, il dominio aziendale. Dai file attuali sono già stati tolti.
- Rendere pubblico il repository esistente pubblicherebbe anche la storia.

## Decisione (opzione B)
- **Quando:** solo quando l'utente dice di essere pronto.
- **Come:**
  - il repository attuale viene rinominato `iago-archivio` e resta privato, con tutta la storia e le PR;
  - un nuovo `giovannilombi/iago` pubblico nasce con un **unico commit** dello stato di `main`. Il nome resta quello del feed di Sparkle;
  - prima della pubblicazione si cercano di nuovo i nomi reali nei file, e si pubblica la 1.0.0 con `scripts/release.sh 1.0.0 --github`.
- **Regole che valgono da subito:**
  - mai dati reali nel codice, nei test, negli esempi delle istruzioni ai modelli, nei documenti e negli screenshot. Si usano nomi inventati (Acme, Rossi, Anna…);
  - gli screenshot si fanno dall'archivio dimostrativo (ADR-0061).
- **Scartate:**
  - A, pubblicare così com'è: esporrebbe i nomi nella storia;
  - C, riscrivere la storia: GitHub conserva le copie legate alle PR, quindi non è sicuro.

## Conseguenze
- La storia completa resta consultabile solo nell'archivio privato.
- Le PR successive vivono nel repository pubblico.
