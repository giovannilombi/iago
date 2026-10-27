# IAGO — Stato del progetto

> Il punto di ripartenza per chiunque lavori su IAGO, persone e sessioni di Claude Code.
> **Va aggiornato alla fine di ogni lavoro**, nella stessa PR: cosa è cambiato, cosa resta aperto.
> Ultimo aggiornamento: **27 ottobre 2026**.

## In breve
- **Versione:** 1.0.0-beta, non distribuita. La 1.0.0 sarà la prima versione distribuibile.
- **Repository:**
  - `giovannilombi/iago`, privato, nato con un solo commit "IAGO 1.0.0-beta" (tag `v1.0.0-beta`);
  - `giovannilombi/iago-archivio`, privato, con la storia di sviluppo precedente (contiene dati reali di prova: non va mai reso pubblico).
- **Autori:** Giovanni Lombi; dalle versioni successive alla 1.0.0-beta, Giovanni Lombi e Gianluca Sestito (ADR-0065).
- **Fasi:** 0, 1, 2 e 3 sviluppate e unite su `main`. La fase 4 (condivisione) aspetta una decisione (ADR-0057).
- **Test automatici:** 256 nei pacchetti, tutti verdi.

## Cosa fa oggi IAGO
La descrizione completa è nel [README](../README.md). In sintesi:
- registra le call su due tracce (sistema e microfono) e le trascrive sul Mac (whisper.cpp o Parakeet);
- importa email, documenti, PDF, immagini, trascrizioni di Teams, anche da cartelle sorvegliate;
- organizza per cliente › progetto › stream, con categorie (che decidono la forma della sintesi) e tag;
- estrae punti chiave (decisioni, attività, tappe) con la loro evoluzione nel tempo;
- sintesi per categoria, ricerca per parole e per significato, "Chiedi a IAGO" con fonti e "Allarga contesto";
- motore locale MLX dentro l'app, Claude facoltativo via MCP;
- barra di registrazione e barra di ascolto, Attività, guida integrata, tour, aggiornamenti con Sparkle.

## Aperto, in ordine di priorità
1. **Revisione tecnica** del collega e decisione sulla distribuzione.
2. **Prove di accettazione** con [`docs/prove-tester.md`](prove-tester.md), una issue "Prove" per tester (vedi [README-collaborators](../README-collaborators.md#6-prove)).
3. **Verifiche dal vivo ancora da fare:**
   - il microfono di Teams funziona mentre IAGO registra (dopo il ritiro di ADR-0053);
   - l'icona di IAGO nelle notifiche di macOS.
4. **ADR proposti, da decidere:**
   - ADR-0057, progetti condivisi tramite una cartella cloud (progetto in [`docs/design/sync-cartella-condivisa.md`](design/sync-cartella-condivisa.md)); quando accettato supera il backend di ADR-0012 e si apre la fase 4;
   - ADR-0067, MiniCPM al posto di Qwen 3.5 4B o in aggiunta: servono prove.
5. **Distribuzione** (ADR-0059, ADR-0060, ADR-0065): senza account Apple a pagamento l'app non è notarizzata e chi la installa deve fare "Apri comunque". Si distribuisce con il **DMG** di `scripts/release.sh`. **Da verificare prima** su un Mac o un account utente pulito: "Apri comunque" una sola volta, aggiornamento con Sparkle senza un nuovo blocco e con i permessi conservati, durata del certificato gratuito e cosa succede alla scadenza. Per distribuire: repository pubblico, `scripts/release.sh 1.0.0 --github`, tabella Versioni del README, attivazione di GitHub Pages per il sito (ADR-0068) e `https://giovannilombi.github.io/iago/` come "Website" nella sezione About del repository.
6. **Dopo:**
   - prove approfondite della qualità della trascrizione su call vere (motori, diarizzazione);
   - nomi degli speaker riconosciuti tra call diverse;
   - rifiniture del grafo.

## Ultime modifiche
- **2026-10-27:** Claude fa sintesi e proposte al posto del motore (ADR-0071): «Copia per Claude» nella scheda, strumenti MCP `recent_items`, `summary_template`, `set_summary`, `propose_suggestions` con le citazioni verificate da IAGO, annullabili. «Segna momento con screenshot» e scorciatoie in tutte le app ⌃⌥M, ⌃⌥S, ⌃⌥R (ADR-0072): schermate cifrate nella call, testo letto con l'OCR del Mac nella trascrizione, nella ricerca e nelle sintesi; immagini a Claude solo se l'utente lo sceglie; nuovo permesso Registrazione schermo. Distribuzione con DMG; le copie compilate da sorgente non cercano aggiornamenti (modifica di ADR-0059).
- **2026-10-27:** coda unica del motore (ADR-0069): trascrizione, motore e ricerca uno alla volta, la chat interrompe il lavoro in sottofondo, limiti di memoria di MLX e pausa con la pressione di memoria; sotto i 32 GB proposte e sintesi automatiche spente di default (nuovo interruttore «Sintesi automatiche») e modello liberato a fine lavoro; Gemma 4 12B non usabile sotto i 24 GB. Provenienza dei risultati (ADR-0070): ogni sintesi, proposta e punto chiave confermato dice quale modello o se Claude l'ha prodotto, con «modello piccolo» sotto i 9B (migrazione `v18-provenance`).
- **2026-10-27:** JSON importabili (trascinati, da file o incollati), mostrati in ordine; CSV, XML, YAML e gli altri file di testo importabili. Menu IAGO, Modifica e Finestra: ⌘C, ⌘V, ⌘X, ⌘A, ⌘Z, ⌘W e ⌘, funzionano nei campi di testo e nelle finestre (prima solo il tasto destro). Limite rigido per richiesta al motore: una riga enorme (un JSON compatto) non satura più la memoria.
- **2026-10-25:** nessun indirizzo email personale nel repository (modifica di ADR-0065). La storia è stata riscritta con gli indirizzi anonimi di GitHub e `giovannilombi/iago` ricreato, perché le PR chiuse conservavano i vecchi commit: le PR #1 e #2 non ci sono più (il loro contenuto è in `main`), le issue sono state trasferite. Controlli in `pre-commit`, `commit-msg`, nuovo `pre-push` e nuovo workflow `privacy.yml` su GitHub. Link al sito di documentazione in cima al README.
- **2026-10-24:** sito di documentazione VitePress su due livelli, Uso e Tecnico (ADR-0068), pronto in locale; online quando il repository diventa pubblico. Documentazione obbligatoria a ogni commit (controllo dei commit). Corretti la guida e il tour sul clic dell'icona (il clic apre il menu, il clic destro avvia e mette in pausa, ADR-0026) e `docs/installazione.md` (aggiornamenti, eco). Corretto il blocco della CI sui test di IAGOIngest (HTML senza WebKit, limiti di tempo).
- **2026-10-24:** repository pulito e 1.0.0-beta (ADR-0065); controlli automatici sui commit (niente dati reali, niente co-autore IA, co-autori del team); esempio iniziale in un archivio nuovo e stream fissabili in evidenza (ADR-0066); ADR-0067 su MiniCPM; documenti per collaborare.
- **2026-10-21:** barra di ascolto; contesto in "Chiedi a IAGO" con "Allarga contesto"; tolta l'icona accanto alla categoria; cancellazione dell'eco di macOS ritirata (ADR-0053) e pulizia dell'eco dopo la registrazione rifiutata (ADR-0064).

## Come ripartire con una sessione pulita
1. Leggere [`CLAUDE.md`](../CLAUDE.md), questo file e [`README-collaborators.md`](../README-collaborators.md).
2. `git status`, `git log --oneline -5`, `gh pr list`: lavorare su un branch nuovo da `main` aggiornato.
3. Prima di un lavoro su un'area, leggere gli ADR collegati (indice in [`docs/adr/README.md`](adr/README.md)).
