# ADR-0059 — Distribuzione senza notarizzazione

- Stato: accettato
- Data: 2026-10-21
- Riferimenti: CLAUDE.md › Piattaforma (firma Apple Development, Personal Team), › Regole (nessun servizio a pagamento); ADR-0056; `docs/installazione.md`, guida › Installazione

## Contesto
Notarizzare un'app richiede l'Apple Developer Program, che è a pagamento. IAGO è firmato con un Apple ID gratuito (Personal Team), con hardened runtime e bundle ID fisso.

## Decisione
- **Distribuzione:** zip firmato con la stessa identità, dalle GitHub Releases, senza notarizzazione.
- **Primo avvio:** la guida, il README e `docs/installazione.md` spiegano **"Apri comunque"** (Impostazioni di Sistema › Privacy e sicurezza).
- **Aggiornamenti:** passano da Sparkle (ADR-0056), che installa solo zip firmati EdDSA dalla chiave dello sviluppatore.
- **Permessi:** firma e bundle ID non cambiano mai, così macOS conserva i permessi (microfono, audio di sistema, Accessibilità, Calendario) da una versione all'altra.

## Conseguenze
- Chi installa deve fare un passaggio in più la prima volta.
- Se un giorno arriverà un account a pagamento, si aggiunge la notarizzazione allo script di rilascio, senza cambiare il resto.

## Modifica del 2026-10-27 (DMG e build da sorgente)
- **La prima installazione è un DMG** (`IAGO-x.y.z.dmg`) con IAGO e il collegamento ad Applicazioni, firmato con la stessa identità dell'app; lo zip resta per gli aggiornamenti di Sparkle. Il passaggio "Apri comunque" resta, una volta sola.
- **Le copie compilate dal codice sorgente non cercano aggiornamenti** (`IAGODistribution` in `Info.plist`, `YES` solo nelle build di `scripts/release.sh`): chi sviluppa si aggiorna con git. Altrimenti Sparkle sostituirebbe la sua build con quella pubblicata, firmata da un altro, e macOS chiederebbe di nuovo tutti i permessi.
- Chi sviluppa e vuole provare il DMG lo installa su un altro account utente o su un altro Mac: due copie di IAGO sullo stesso account si contendono permessi e archivio.
- **Da verificare prima della distribuzione:** "Apri comunque" una sola volta su un Mac pulito; aggiornamento con Sparkle senza un nuovo blocco e con i permessi conservati; durata del certificato gratuito e cosa succede alla scadenza.
