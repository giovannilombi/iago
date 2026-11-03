# ADR-0088 — Ordine delle sezioni dell'elemento e barra laterale

- Stato: accettato
- Data: 2026-11-03
- Riferimenti: ADR-0084 (dettaglio dell'elemento), ADR-0038 (cliente › progetto › stream), ADR-0087 (colonne per sezione); richieste dell'utente del 2026-11-03

## Contesto
- Nel dettaglio dell'elemento la sintesi e le proposte venivano prima dell'audio, e la trascrizione stava dopo segnalibri e schermate: chi apre una call vuole prima ascoltarla e ritrovare i momenti segnati.
- L'ordine fisso non va bene per tutti: c'è chi guarda prima la sintesi, chi le note.
- Nella barra laterale il **＋** per un nuovo progetto o cliente stava in basso a sinistra, lontano dai progetti. Sull'intestazione di un cliente la freccia e il **+** non rispondevano al clic, e la finestra del nuovo progetto non si apriva mai, come quella del nuovo stream.
- Con la barra laterale stretta i nomi lunghi dei progetti si leggono solo aprendoli.
- La linea tra colonna centrale e destra attraversava la barra degli strumenti in alto.

## Decisione
- **Ordine di base delle sezioni:** Audio, Segnalibri, Schermate, Sintesi, Trascrizione (o Email e Contenuto), Proposte, Punti chiave, Note, Collegamenti, File. Le tile seguono lo stesso ordine.
- **Ordine scelto dall'utente:** a destra del titolo di ogni sezione c'è una maniglia discreta (≡). Si trascina il titolo:
  - tutte le sezioni mostrano solo l'intestazione e una frase in cima spiega cosa fare;
  - la sezione trascinata è evidenziata e le altre si spostano mentre passa;
  - al rilascio le sezioni tornano aperte o chiuse come prima.
- L'ordine è **uno solo per tutti gli elementi**, conservato tra un avvio e l'altro. Impostazioni › Generale › Dettaglio elemento › *Ripristina l'ordine delle sezioni* torna a quello di base. Audio e File sono sempre aperte, ma si spostano come le altre.
- **Barra laterale:**
  - niente titolo «Progetti»: sopra clienti e progetti, a destra, c'è **Aggiungi**, con il menu *Aggiungi:* › *Cliente…*, *Progetto…*;
  - in fondo resta solo il **Cestino**, come riga uguale alle viste in alto;
  - sull'intestazione di un cliente resta il **+**, che apre il nuovo progetto con quel cliente già scelto e non modificabile. La freccia sparisce: il cliente si apre con il tasto destro › *Apri*;
  - dopo **due secondi** sul nome di un progetto compare il nome intero.
- **Barra degli strumenti intera:** il divisore tra colonna centrale e destra si ferma sotto la barra in alto, che resta un pezzo solo con la sola linea della barra laterale.

## Conseguenze
- L'ordine sta in `detail.sectionOrder`; il tour dimostrativo non lo legge né lo scrive. Una sezione nuova che l'ordine salvato non conosce prende il suo posto di base.
- Le finestre del nuovo progetto e del nuovo stream le mostra la finestra principale (`AppModel.newProject`, `newStreamProject`): dentro la lista della barra laterale non comparivano.
- Il divisore si accorcia con una maschera sulla sua vista (`ContentColumnWidth`), perché la vista divisa di SwiftUI non lascia scegliere quali colonne passano sotto la barra.
- La guida (capitoli 06, 07 e 16, in italiano e in inglese) descrive i cambiamenti; le schermate si rifanno quando la grafica è stabile.
