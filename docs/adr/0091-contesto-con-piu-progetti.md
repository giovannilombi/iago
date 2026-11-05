# ADR-0091 — Contesto di «Chiedi a IAGO» con più progetti

- Stato: accettato
- Data: 2026-11-05
- Riferimenti: ADR-0017 (contesto etichettato), ADR-0049 (ricerca per significato, proposte e chat), ADR-0038 (cliente › progetto › stream); richiesta dell'utente del 2026-11-05

## Contesto
- Il contesto di *Chiedi a IAGO* seguiva la sezione aperta: un progetto, un cliente, uno stream o tutta la memoria. *Allarga contesto* saliva di un livello alla volta.
- Spesso la domanda riguarda due o tre progetti precisi, magari di clienti diversi: l'unica strada era tutta la memoria, con risposte più rumorose.
- Il contesto cambiava da solo a ogni cambio di sezione, anche quando l'utente voleva tenerlo.

## Decisione
- **Più progetti insieme:** un nuovo ambito, `SearchScope.projects`, con almeno due progetti in ordine. `SearchScope.chosen(_:)` sceglie la forma giusta: nessun progetto è tutta la memoria, uno è il progetto, due o più sono i progetti scelti. Lo seguono ricerca, frammenti per la risposta, novità, proposte dei punti chiave e punti chiave nelle risposte.
- **Striscia del contesto** in cima alla chat: un'etichetta per ogni progetto, con la ✕ per togliere il singolo progetto quando sono più d'uno, e una riga che dice se il contesto *Segue la sezione aperta* o è *Scelto da te: resta anche cambiando sezione*.
- **Un solo pulsante, «Cambia contesto»**, con il menu:
  - *Aggiungi progetti…*;
  - *Restringi contesto…*, spento con un solo progetto;
  - *Contesto globale*, spento quando è già tutta la memoria;
  - *Segui la sezione aperta*.
- **Scelta dei progetti:** una finestrella con tutti i progetti raggruppati per cliente, più *Senza cliente*, con la casella del cliente, il conteggio dei progetti scelti e un campo di ricerca. *Restringi* partendo da tutta la memoria comincia con tutti i progetti spuntati.
- **La scelta resta** cambiando sezione e tra un avvio e l'altro (`chat.context`), finché l'utente non sceglie *Segui la sezione aperta*. Il tour dimostrativo non la legge né la scrive.
- **Cambiare contesto** apre una conversazione nuova e ripete l'ultima domanda nel nuovo contesto.

## Conseguenze
- Nessun cambio allo schema: una conversazione con più progetti ha `scopeKind` «projects» e gli identificativi separati da virgole in `scopeId`.
- *Allarga contesto* resta per salire di un livello; *Cambia contesto* serve per scegliere con precisione.
