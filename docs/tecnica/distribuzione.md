# Distribuzione e aggiornamenti

## Senza App Store e senza notarizzazione (ADR-0059)
- L'App Store richiede la sandbox, che non permette di registrare l'audio delle altre app.
- La notarizzazione richiede un account Apple a pagamento: IAGO è firmato con un Apple ID gratuito (Apple Development) e chi lo installa fa **"Apri comunque"** la prima volta.
- Cambiare firma o bundle ID farebbe richiedere di nuovo tutti i permessi: non si fa.
- **DMG** (modifica del 2026-10-27, poi ADR-0097): la prima installazione è un DMG; lo zip resta per Sparkle.
  - **Contenuto:** IAGO, il collegamento ad *Applicazioni* e `Leggimi - Read me.html`, cioè le istruzioni in italiano e inglese con i passi di «Apri comunque» e il comando del Terminale.
  - **Sfondo:** nasce da `scripts/dmg/background.html`; `scripts/dmg/make-background.sh` lo disegna a 1x e 2x con Chrome senza finestra e lo salva in `background.tiff`, che è nel repository.
  - **Posizioni delle icone:** sono in `scripts/dmg/settings.py`, e vanno tenute allineate allo sfondo.
  - **Disposizione:** la scrive `dmgbuild` (BSD) senza Finder, in `build/venv-dmg`.
  - **Script:** `scripts/dmg/make-dmg.sh <IAGO.app> <versione>` fa il DMG; lo usa `release.sh`, e da solo rifà il DMG di un'app già compilata. Si ferma se le istruzioni sono vuote o senza icona.
  - **Quarantena:** su un altro Mac il DMG scaricato è in quarantena. Il primo passo per chi installa è `xattr -d com.apple.quarantine ~/Downloads/IAGO.dmg`: un DMG senza quarantena non la passa all'app (ADR-0097, modifica).
- **Build da sorgente senza aggiornamenti:** `IAGO_DISTRIBUTION` (in `Config/Base.xcconfig`, `NO`) finisce in `Info.plist` come `IAGODistribution`; solo `scripts/release.sh` compila con `YES`. `UpdateService` avvia Sparkle solo se è `YES`: una copia compilata da chi sviluppa si aggiorna con git e non viene sostituita da quella pubblicata, firmata da un altro, che farebbe richiedere tutti i permessi.

## Aggiornamenti con Sparkle (ADR-0056)
- **Sparkle 2.10** legge `https://github.com/giovannilombi/iago/releases/latest/download/appcast.xml`.
- Ogni release è un archivio firmato **EdDSA**; la chiave pubblica è nell'app (`SUPublicEDKey`), quella privata nel Portachiavi di chi pubblica. IAGO installa solo versioni firmate dalla stessa chiave.
- **Versioni maggiori obbligatorie:** l'appcast le segna come *critical*. Da quando IAGO le vede ci sono 2 giorni di margine (`UpdateService.mandatoryDeadline`, data in `update.mandatoryFirstSeen`), con il termine e *Aggiorna ora…* nel menu; poi IAGO non avvia nuove registrazioni, trascrizioni, sintesi e proposte (`AppModel.blockedByUpdate`). Una registrazione in corso continua.
- Funziona perché il repository è **pubblico** (dal 7 novembre 2026, prima release 1.3.0-beta).

## Fare una release
```sh
scripts/release.sh 1.0.0 --notes "Novità…" --github
```
1. Aggiorna versione e build in `project.yml` (`1.1.0`, oppure `1.1.1-beta` per una beta).
2. Compila la Release firmata e la verifica con `codesign`.
3. Crea lo zip, lo firma per Sparkle e scrive `appcast.xml`.
4. Crea il **DMG** con `dmgbuild`, mettendo nelle istruzioni l'icona dell'app, e lo firma con la stessa identità dell'app. Lo copia anche come `IAGO.dmg`, il nome fisso del link in cima al README.
5. Con `--github` pubblica la release, segnata come ultima, con i due DMG, lo zip, l'appcast e le istruzioni di installazione nelle note.

**Da verificare prima di distribuire** (prova su un Mac o un account utente pulito): "Apri comunque" una sola volta, aggiornamento con Sparkle senza un nuovo blocco e con i permessi conservati, durata del certificato gratuito e cosa succede alla scadenza.

Dopo ogni release si aggiorna la tabella **Versioni** del README.

## Repository e versioni (ADR-0060, ADR-0065)
- `x.y.z-beta` finché non si decide di distribuire, poi senza `-beta`: il terzo numero sale a ogni PR che cambia l'app, il secondo con un gruppo grande di funzioni. Ogni versione ha un tag annotato con le funzioni, che fa da punto di ripristino (README › Tornare a una versione precedente).
- Dal 7 novembre 2026, con la 1.3.0-beta, si resta in beta per scelta dell'utente: si toglie `-beta` quando lo decide lui.
- `giovannilombi/iago` è **pubblico** dal 7 novembre 2026 ed è nato con un solo commit; la storia precedente è in un archivio privato separato, che non diventa pubblico.
- Il sito di documentazione è su GitHub Pages (`deploy.yml`, ADR-0068).
