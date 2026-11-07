# ADR-0097 — DMG con sfondo e istruzioni, release sul repository pubblico

- Stato: accettato
- Data: 2026-11-07
- Modifica: ADR-0059 (distribuzione senza notarizzazione), ADR-0056 (aggiornamenti)
- Riferimenti: ADR-0060 (repository pubblico), ADR-0068 (sito di documentazione); richiesta dell'utente del 2026-11-07, grafica approvata su un'anteprima

## Contesto
- Il DMG conteneva solo IAGO e il collegamento ad Applicazioni. Chi lo apriva non sapeva che al primo avvio macOS blocca l'app, né come sbloccarla: le istruzioni erano solo nel README e sul sito.
- Gli aggiornamenti arrivano con Sparkle dalle release di `giovannilombi/iago` (ADR-0056). Finché il repository è privato, chi non ha accesso non riceve nulla. L'indirizzo resta scritto in ogni copia installata, quindi va deciso prima della prima distribuzione.
- L'idea di un eseguibile nel DMG che sblocchi Gatekeeper non funziona: un programma che arriva con lo stesso download viene bloccato come IAGO.

## Decisione
- **Release su questo repository, reso pubblico.**
  - L'indirizzo degli aggiornamenti non cambia: `releases/latest/download/appcast.xml`.
  - Ogni release allega anche `IAGO.dmg`, con nome fisso, così il link in cima al README scarica sempre l'ultima versione.
- **DMG con sfondo** (`scripts/dmg`):
  - la finestra misura 660×400;
  - in alto c'è «Trascina IAGO in Applicazioni / Drag IAGO to Applications»;
  - IAGO e Applicazioni sono uniti da tre frecce rossa, gialla e verde, con il contorno scuro come nel logo;
  - in basso, una fascia gialla invita a leggere le istruzioni, in italiano e inglese;
  - il volume ha l'icona di IAGO.
- **Come si fa il DMG:**
  - lo sfondo nasce da `background.html`: `make-background.sh` lo disegna a 1x e 2x con Chrome senza finestra e lo salva in `background.tiff`, che è nel repository;
  - la disposizione la scrive `dmgbuild` (BSD), senza pilotare Finder, in un ambiente Python dentro `build/` creato da `scripts/release.sh`.
- **Istruzioni nel DMG:** il file `Leggimi - Read me.html`, una pagina senza rete con il cambio di lingua.
  - **Modo consigliato:** quattro passi illustrati (trascinare, aprire e premere *Fine*, *Privacy e sicurezza › Apri comunque*, password).
  - **Modo veloce:** il comando da copiare nel Terminale, `sudo xattr -dr com.apple.quarantine /Applications/IAGO.app`. La pagina dice in parole semplici cosa fa e perché chiede la password, e raccomanda di usarlo solo per app di cui ci si fida.
  - In apertura due pulsanti portano ai passi o al modo veloce («Allergico ai menu? Un comando nel Terminale e via»).
- **Niente eseguibile di sblocco nel DMG**, per il motivo detto sopra.

## Conseguenze
- Chi scarica IAGO trova tutto nel DMG, anche senza aver letto il README.
- `scripts/release.sh` richiede Python 3, la prima volta la rete per installare `dmgbuild`, e il Portachiavi con le chiavi di firma.
- **Da verificare su un Mac pulito**, prima della prima distribuzione:
  - l'aspetto del DMG in modalità chiara e scura: in modalità scura Finder può scrivere i nomi delle icone in bianco;
  - «Apri comunque» e il comando del Terminale;
  - un aggiornamento con Sparkle che arrivi senza un nuovo blocco.
- **Schermate:** quelle delle istruzioni sono disegnate. Si possono sostituire con le schermate reali di macOS quando la grafica di sistema cambia.
