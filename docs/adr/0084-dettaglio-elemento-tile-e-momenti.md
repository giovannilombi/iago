# ADR-0084 — Dettaglio dell'elemento: tile, barra fissa e momenti

- Stato: accettato (1.2.11-beta); ordine delle sezioni rivisto in ADR-0088
- Data: 2026-11-02
- Riferimenti: ADR-0018 (l'elemento è un evento tipizzato), ADR-0049 («Chiedi a IAGO» in basso a destra), ADR-0072 (segna momento con screenshot); review board interna del 2026-11-02, prototipo approvato dall'utente

## Contesto
- Il dettaglio di una call è lungo: sintesi, punti chiave, proposte, note, player, segnalibri, schermate, trascrizione, collegamenti, file.
- Le sezioni sono già a fisarmonica (`SectionBox`) e le trascrizioni lunghe hanno un'altezza massima. Però lo stato aperta/chiusa vale per tipo di sezione in tutta l'app, e chi apre un elemento non vede a colpo d'occhio cosa contiene.
- Segnalibri e schermate sono in sezioni separate: nella trascrizione le schermate compaiono come riga di testo, i segnalibri no. Il player non mostra dove sono i momenti.
- Le sezioni vuote occupano lo stesso spazio di quelle piene.

## Decisione
- **Tile piccole sotto il titolo**, basse e lunghe, che vanno a capo da sole, un solo gruppo:
  - ogni tile ha il nome della sezione e un solo dato: il numero di voci, «✓» per la sintesi;
  - la **Trascrizione** dice la fonte per esteso: «IAGO», «Teams» o «IAGO + Teams»; «…» mentre è in corso, «—» se non c'è. Per email e documenti: «Email ✓» o «Contenuto ✓»;
  - una tile vuota è tratteggiata e grigia;
  - un clic apre la sezione e ci porta lì.
- **Sotto il titolo**, cliente › progetto su una riga e data · durata · tipo sulla successiva.
- **Barra fissa allo scorrimento:** quando le tile escono dallo schermo compare in alto una barra semitrasparente con il titolo, a capo cliente › progetto · data · durata, e le tile in miniatura con la sezione in cui ci si trova evidenziata. Tornando in cima sparisce.
- **Torna su:** un pulsante rotondo ↑ in basso a destra, sopra «Chiedi a IAGO» a distanza fissa; se «Chiedi a IAGO» è nascosto, il ↑ prende il suo posto. Compare solo con la barra fissa.
- **Aperta o chiusa per elemento:** ogni elemento ricorda le sezioni aperte e chiuse lì dentro. Il punto di partenza di ogni sezione si sceglie in Impostazioni › Generale › Dettaglio elemento, con «Riapplica a tutti gli elementi…» per dimenticare le scelte fatte nei singoli elementi. **File** è sempre aperta e sta in fondo.
- **Sezioni vuote ridotte all'intestazione:** tratteggiata e grigia, senza freccia, con una frase propria («Nessun collegamento ad altri elementi») e, se serve, l'azione utile (per esempio «Collega…»).
- **Player con i momenti:**
  - sul player una tacca per ogni segnalibro e schermata, del loro colore;
  - sotto, un solo momento alla volta (miniatura, tipo, titolo, minuto) con ‹ › e «N di M». All'apertura è il prossimo rispetto a dove si è, mentre si ascolta segue l'audio; un clic su una tacca lo sceglie;
  - altezza fissa, niente scorrimento laterale, mai vuoto; senza momenti resta solo il player.
- **Momenti nella trascrizione:** segnalibri e schermate compaiono nel loro minuto, con il loro colore. Si possono spegnere in Impostazioni, come le tacche sul player.

## Conseguenze
- Lo stato aperta/chiusa passa da una preferenza per tipo di sezione a una per elemento, con i default in Impostazioni: le scelte globali fatte finora diventano i nuovi default.
- La barra fissa e il ↑ richiedono di leggere la posizione di scorrimento del dettaglio (macOS 15). Il ↑ sta nello stesso livello di «Chiedi a IAGO», così i due non si sovrappongono mai.
- La guida (in italiano e in inglese) e le sue schermate vanno rifatte per il dettaglio dell'elemento.
- Le sezioni Segnalibri e Schermate restano: tile, player e trascrizione sono altri modi di arrivarci.
