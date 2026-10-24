# ADR-0056 — Aggiornamenti dell'app

- Stato: accettato (A, decisa dall'utente il 2026-10-21: il repository diventa pubblico)
- Data: 2026-10-21
- Riferimenti: CLAUDE.md › Rete e privacy; memoria "pre-distribuzione"; richiesta utente 2026-10-15 e 2026-10-21 (distribuire presto, anche ai colleghi)

## Contesto
- IAGO deve controllare se c'è una versione nuova, chiedere se installarla e, per le versioni importanti, poterla rendere obbligatoria.
- Il repository GitHub è privato: un utente senza account non può scaricare né le release né un file di aggiornamenti.
- Non c'è un account Apple a pagamento, quindi l'app non è notarizzata (vedi `docs/installazione.md`).
- L'azienda ha un OneDrive condiviso, che l'utente vuole usare anche per la sincronizzazione (fase 4).

## Opzioni
### A. Sparkle (MIT) con un repository pubblico solo per le release
- Un repository pubblico `iago-releases` contiene `appcast.xml` e i file `.zip`. IAGO controlla una volta al giorno, scarica, verifica la firma EdDSA e installa.
- Sparkle gestisce gli aggiornamenti critici (`criticalUpdate`) e la versione minima.
- **Contro:**
  - è una **nuova eccezione di rete** in CLAUDE.md;
  - l'app diventa scaricabile da chiunque abbia il link;
  - per i colleghi non serve, perché hanno già OneDrive.

### B. Aggiornamenti dalla cartella OneDrive aziendale (consigliata)
- **Pubblicare:** lo script di rilascio copia in una cartella condivisa di OneDrive, per esempio `IAGO/Aggiornamenti`:
  - `IAGO-x.y.z.zip`;
  - `aggiornamento.json` con versione, versione minima, note e SHA-256.
- **Ricevere:** IAGO legge la cartella, che è sincronizzata sul Mac da OneDrive. Quando c'è una versione più nuova:
  - propone **Aggiorna ora / Più tardi**;
  - sotto la **versione minima** l'aggiornamento è obbligatorio: IAGO lo chiede all'avvio e non avvia registrazioni finché non è fatto. Le registrazioni in corso non vengono mai interrotte.
- **Controlli prima di installare:**
  - SHA-256 del file;
  - l'app nuova ha la **stessa firma e lo stesso Team ID** di quella installata. Così non cambiano bundle e permessi, e un file manomesso viene rifiutato.

  Poi IAGO sostituisce l'app in Applicazioni e si riavvia.
- **Pro:**
  - IAGO **non fa nessuna connessione di rete**: la regola resta intatta;
  - funziona per tutta l'azienda con quello che c'è già;
  - è coerente con la sincronizzazione su OneDrive della fase 4.
- **Contro:** fuori dall'azienda non funziona. Se un giorno servirà, si aggiunge A.

## Decisione
**A, Sparkle 2.10.0 con le release del repository**, che diventa pubblico.
- **Dove:**
  - feed `https://github.com/giovannilombi/iago/releases/latest/download/appcast.xml`;
  - lo zip è allegato a ogni release;
  - firma EdDSA con la chiave nel Portachiavi dello sviluppatore (account `iago`). La chiave pubblica è in Info.plist (`SUPublicEDKey`).
- **Controllo:** una volta al giorno (`SUScheduledCheckInterval`), disattivabile in Impostazioni › Generale › Aggiornamenti, con "Controlla ora" anche dal menu del pappagallo. Ogni controllo e ogni installazione vanno nel registro accessi (`update`).
- **Versioni minori:** proposte (installa, più tardi, salta).
- **Versioni maggiori:** obbligatorie. Lo script le segna `criticalUpdate`, Sparkle non offre "salta", e IAGO non avvia nuove registrazioni finché non sono installate. Quelle in corso non vengono mai interrotte.
- **Rilascio:** `scripts/release.sh x.y.z --notes "…" --github`, che:
  - imposta versione e build;
  - compila la Release firmata;
  - crea lo zip e lo firma con `sign_update`;
  - scrive `appcast.xml`;
  - crea la release su GitHub con zip e appcast.
- **Eccezione di rete in CLAUDE.md:** il controllo e il download degli aggiornamenti da GitHub Releases, firmati.
- **B (cartella OneDrive)** resta un'idea per le installazioni aziendali senza accesso a GitHub; non si implementa.

## Conseguenze
- Prima di aprire il repository va controllato che non contenga dati personali né registrazioni: la spec, HANDOVER.md e `Test-recordings/` sono già esclusi da git.
- Se si perde la chiave EdDSA, gli utenti non accettano più gli aggiornamenti: va salvata (`generate_keys --account iago -x <file>`) in un posto sicuro.
