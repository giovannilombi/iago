<!-- icona: checkmark.seal -->
# Punti chiave e lavoro aperto

I punti chiave sono di sei tipi, in due famiglie.

**Memoria:** cose avvenute, che restano.
- **Decisione:** qualcosa di deciso. Vale finché un'altra non la sostituisce.
- **Tappa:** un fatto importante (firma, consegna, kickoff).

**Lavoro aperto:** cose da chiudere.
- **Attività:** cosa fare, con chi e per quando; può avere una **checklist** di sotto-voci da spuntare.
- **Punto da chiarire:** una domanda che aspetta risposta.
- **Rischio:** cosa può andare storto, con la gravità (alta, media, bassa). Se succede, lo segni *Diventato problema*.
- **Richiesta:** cosa chiede il cliente; la accogli, la rifiuti o la trasformi.

![Punti chiave nella timeline](img/punti-chiave.png)

## Traccia e Gestisci
Ogni progetto ha il suo modo, scelto con la pillola **Gestisci ▾** accanto al nome del progetto (o in Impostazioni › Progetti). I dati sono gli stessi: passando dall'uno all'altro non perdi nulla.
- **Gestisci** (predefinito): tutti i tipi e tutti gli stati, anche *In corso* e *Bloccata*; la priorità, le dipendenze («dipende da»), la stima, la data d'inizio, le ricorrenze, la **Kanban** e il **Riepilogo** completo.
- **Traccia:** per i progetti semplici. Tutti i tipi, con responsabile, scadenza, «in attesa di» e checklist; gli stati sono *Aperta*, *In attesa*, *Fatta*, *Annullata*; niente Kanban.

Da fare e Punti chiave raccolgono tutti i progetti: ogni voce si vede nel modo del suo progetto.

## Crearli
Da un segnalibro, da una frase della trascrizione (tasto destro), da un documento, da una nota (*Promuovi*), a mano (*Aggiungi* nella timeline), oppure confermando una **proposta** del motore o di Claude. Ognuno ha titolo, descrizione, data, persone, tag, stream e la **fonte** (con il minuto della call).

Per il **responsabile** scegli tra le persone che IAGO conosce, oppure ne scrivi una nuova; se somiglia a un nome noto IAGO chiede «Intendi Marco Rossi?». Quando scrivi qualcuno in **In attesa di**, la voce passa *In attesa*.

## Chiudere
- **Attività:** *Segna come fatta*. Una ricorrente (ogni giorno, settimana, mese, anno) crea da sola la successiva.
- **Punto da chiarire:** *Chiarisci…* con la risposta; con *Diventa decisione* la risposta diventa anche una decisione.
- **Richiesta:** *Accogli…* (crea una o più attività nate da lei), *Rifiuta…* con il motivo, *Trasforma in…* un altro tipo.
- **Rischio:** *Diventato problema*, *Risolto* o *Non più rilevante*.
- Su qualsiasi voce: *Nuova attività da questo* e *Riapri*.

## Superare e chiudere con un'altra voce
Una voce può **chiuderne altre**, anche di tipo diverso: una tappa «Firmato il contratto» completa un'attività, una decisione risponde a un punto da chiarire o accoglie una richiesta. La riga lo dice con il verbo giusto: *sostituisce*, *risponde a*, *accoglie*, *completa*. Le voci chiuse tornano aperte se togli il legame. La sezione **Evoluzione** mostra tutte le voci collegate in ordine; puoi dare un nome alla catena.

## Come si vedono
- Aperta: icona e colore del tipo, con responsabile e scadenza; la scadenza diventa rossa quando è passata.
- In attesa: «attende Anna · entro 5 nov». Bloccata: l'etichetta *bloccata*.
- Fatta: ✓ verde, testo grigio. Chiarita, accolta o rifiutata: una riga con l'esito.
- Superata o annullata: testo barrato.
- Una voce chiusa da un'altra dello stesso giorno sta sotto di lei.

## Da fare
**Da fare**, nella barra laterale, raccoglie il lavoro aperto di tutti i progetti:
- le tue voci, per scadenza: in ritardo, oggi, questa settimana, più avanti, senza data; poi quelle *Senza responsabile*;
- **Aspetto da altri:** le voci in attesa, con la data promessa e il ritardo;
- le **proposte da confermare**;
- le **checklist fissate** dei progetti, da spuntare qui.

*Mostra chiuse* fa vedere anche le voci chiuse da poco. In Gestisci puoi ordinare per priorità e filtrare per persona.

Se vuoi, una **notifica al mattino** (Impostazioni › Generale) ti dice quante voci scadono oggi, quante sono in ritardo e quante attese sono scadute; un clic apre Da fare.

## Riepilogo
Ogni progetto, cliente e stream ha il **Riepilogo**, il primo pulsante in alto: la prima volta il progetto si apre lì. Occupa tutta la finestra: in alto i numeri (aperte e chiuse per tipo, in ritardo, bloccate); a sinistra ciò su cui agire (scadenze, bloccate, attese, rischi, punti da chiarire, prossime tappe); a destra cosa è cambiato, la sintesi di stato e le checklist. Un clic su una voce la apre nel pannello a destra.

![Riepilogo di un progetto](img/riepilogo.png)
- voci aperte per tipo, prossime scadenze, decisioni e tappe recenti, attese;
- le **checklist del progetto** (per esempio «Consegna finale»): le crei, le fissi in alto e le spunti;
- in Gestisci anche l'avanzamento, i bloccati, i rischi per gravità, *Cosa è cambiato* dall'ultima volta che l'hai aperto e la **Sintesi di stato**: un testo scritto dal motore locale a partire dai punti chiave, da copiare in una mail o da passare a Claude.

## Kanban
In Gestisci, la **Kanban** di un progetto, cliente o stream (o di tutti, da Da fare e da Punti chiave) occupa tutta la finestra e mette il lavoro aperto in colonne: *Da fare*, *In corso*, *In attesa*, *Bloccata*, *Fatta*. Trascinare una scheda in un'altra colonna ne cambia lo stato; in *In attesa* IAGO chiede da chi e fino a quando.

Puoi aggiungere **colonne tue** (per esempio «Da discutere venerdì»): servono a raggruppare e non cambiano lo stato. Nella colonna *Fatta* le voci chiuse da più di 14 giorni vengono archiviate: *Mostra tutte* le fa riapparire, *Archivia* le nasconde di nuovo, e IAGO ricorda la scelta. Un clic su una scheda la apre nel **pannello a destra**; ✕ o Esc lo chiudono. Per tornare alla lista scegli *Elenco* o *Timeline*. La Kanban di tutti lascia fuori i progetti in Traccia; si spegne in Impostazioni › Generale senza perdere colonne e posizioni.

![Kanban di un progetto](img/kanban.png)

## Dove vederli
- **Punti chiave** nella barra laterale: tutti, con filtri per tipo, stato, persona, responsabile, tag.
- In un progetto, **Mostra: Punti chiave** con l'Elenco, la Timeline o la Mappa (vedi Organizzare).
- **Da fare**, **Riepilogo** e **Kanban**, come sopra.
- La **timeline**, insieme a call, email e note.
