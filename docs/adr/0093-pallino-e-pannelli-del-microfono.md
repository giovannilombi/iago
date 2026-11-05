# ADR-0093 — Pallino giallo e pannelli quando il microfono non registra

- Stato: accettato
- Data: 2026-11-05
- Riferimenti: FR-16 (traccia muta), ADR-0004 (microfono che segue l'app di call), ADR-0051 (pannelli di IAGO in alto a destra); richiesta dell'utente del 2026-11-05

## Contesto
- Il pallino dell'icona di IAGO nella barra dei menu diventava giallo quando una traccia restava muta per più di 30 secondi mentre l'altra aveva segnale (FR-16).
- Chi ascolta in silenzio vedeva quindi il giallo dopo 30 secondi, e il rosso tornava appena parlava. L'utente lo leggeva come «registriamo senza microfono», con un ritardo che lo rendeva fuorviante.
- Un microfono staccato o fermo, invece, è un problema vero: la voce dell'utente non finisce nella trascrizione. Va detto subito e in modo chiaro.

## Decisione
- **Rosso**: registrazione con il microfono. **Giallo**: dal microfono non arriva audio, cioè nessun dispositivo o nessun buffer da più di 2 secondi (`SilenceAlarm.micAbsent`, `absentWindow`). Il silenzio non è assenza: un microfono che ascolta manda comunque buffer.
- L'icona si aggiorna ogni secondo, come prima: il giallo arriva entro circa 2 secondi e se ne va appena il microfono riprende.
- **Pannello** in alto a destra, come le proposte di registrazione (ADR-0051):
  - *Il microfono non registra*, appena manca l'audio, con *Scegli il microfono* (Impostazioni › Audio) e *Ignora*. Se l'utente risponde, non torna finché il microfono non riprende e poi si ferma di nuovo;
  - *Il microfono non sente la tua voce*, una volta per registrazione, quando il microfono è muto da più di 30 secondi mentre gli altri parlano. Dice che, se si sta solo ascoltando, va tutto bene.
- L'avviso di FR-16 resta come riga nel menu di IAGO e nella barra di registrazione, non più come pallino giallo. La barra di registrazione mostra anche *Nessun audio dal microfono*.

## Conseguenze
- Il giallo ha un solo significato e arriva in tempo.
- Il pannello della traccia muta compare al massimo una volta per registrazione: chi ascolta a lungo non viene disturbato di continuo.
