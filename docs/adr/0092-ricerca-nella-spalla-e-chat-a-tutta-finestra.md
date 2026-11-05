# ADR-0092 — Ricerca nella spalla destra e «Chiedi a IAGO» a tutta finestra

- Stato: accettato
- Data: 2026-11-05
- Riferimenti: ADR-0036 (indice di ricerca), ADR-0049 (ricerca per significato e chat), ADR-0091 (contesto con più progetti); richiesta dell'utente del 2026-11-05

## Contesto
- La ricerca stava nel campo in alto a destra e i risultati prendevano il posto della colonna centrale; per tornarci c'era la barra *Torna ai risultati*. Con *Chiedi a IAGO* aperto, il campo di ricerca restava visibile e due modi di cercare stavano in due posti diversi.
- Non era chiaro quando usare la ricerca, che trova le parole, e quando chiedere a IAGO, che risponde con le fonti.
- Durante una conversazione lunga la chat aveva poco spazio, e il resto della finestra non serviva.

## Decisione
- **«Cerca» al posto del campo:** nella barra in alto un pulsante *Cerca* (⌘F) apre la ricerca nella spalla destra e mette il cursore nel campo. Resta acceso finché la ricerca è aperta.
- **Ricerca semplice nella spalla**, dove si apre anche *Chiedi a IAGO*, una alla volta:
  - in cima una frase dice cosa fa e quando usarla. Con il modello di ricerca scaricato aggiunge che trova anche i passaggi detti con altre parole;
  - il campo, con i suggerimenti per *#tag* e *categoria:*;
  - i risultati, con ambito e filtri di prima. Un clic apre l'elemento nel dettaglio e i risultati restano nella spalla;
  - la ✕, o Esc, la chiude;
  - in fondo il riquadro «Ti serve una risposta, un riassunto o un confronto?», con *Chiedi a IAGO*.
- **Dalla chat alla ricerca:** nell'intestazione di *Chiedi a IAGO* una lente, *Passa alla ricerca semplice*, apre la ricerca nella stessa spalla.
- **A tutta finestra:** un pulsante nell'intestazione della chat, *A tutta finestra* o *Riduci a pannello*. A tutta finestra restano:
  - la barra laterale;
  - l'elenco delle conversazioni;
  - la conversazione, larga al massimo circa 760 punti;
  - le fonti, che si aprono in un pannello a destra.

  Un clic su una sezione della barra laterale esce dalla vista a tutta finestra.
- **La conversazione resta:** lo stato della chat sta nel modello (`ChatState` in `AppModel`), quindi non si perde passando a tutta finestra e ritorno, né chiudendo e riaprendo la spalla.
- La barra *Torna ai risultati* non c'è più. Il pulsante flottante *Chiedi a IAGO* si nasconde mentre una delle due spalle è aperta.

## Conseguenze
- Ricerca e risposte hanno un posto solo e un comportamento coerente, e ognuna rimanda all'altra.
- Chi vuole ricominciare da capo usa *Nuova conversazione*: chiudere la spalla non azzera più la chat.
