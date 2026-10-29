# IAGO — Prove per i tester

Lista ordinata delle prove, pensata per chi non conosce IAGO. Per ogni prova segna ✅ (funziona), ❌ (non funziona, descrivi cosa vedi) oppure — (non fatta, spiega perché).

Serve:
- un Mac con IAGO installato in `/Applications`;
- un account Microsoft Teams;
- possibilmente il calendario di lavoro sincronizzato nell'app Calendario del Mac (Impostazioni di Sistema › Account Internet).

Le prove non richiedono dati reali: usa riunioni e file di prova.

> Questo documento si aggiorna a ogni nuova funzione.

## 0. Preparazione: permessi
- [ ] 0.1 Apri IAGO › Impostazioni › **Permessi**. Compare la checklist con lo stato di ogni voce.
- [ ] 0.2 Premi **"Attiva quelli che mancano"** e segui i passi uno alla volta. Ogni voce attivata diventa verde da sola entro pochi secondi.
- [ ] 0.3 Dalla checklist, con un clic su una voce ancora da fare, si avvia solo quella voce.
- [ ] 0.4 Alla fine sono attivi almeno tutti gli "Obbligatorio".

## 1. Icona e notifiche
- [ ] 1.1 Nel Dock e nel Finder l'icona di IAGO è il pappagallo.
- [ ] 1.2 Impostazioni › Audio › Riunioni › **"Invia una notifica di prova"**: arriva una notifica con l'icona del pappagallo, non un quadrato bianco.
- [ ] 1.3 Un clic sull'icona di IAGO nella barra dei menu apre il menu (con **Avvia registrazione**); il clic destro, o ctrl-clic, avvia la registrazione, la mette in pausa e la riprende senza aprire il menu. Un clic normale durante una registrazione non la mette in pausa.

## 2. Proposte di registrazione (riunioni)
- [ ] 2.1 Impostazioni › Audio › Riunioni › **"Mostra un esempio di proposta"**: in alto a destra compare un pannello di IAGO con **Registra** e **Ignora**.
- [ ] 2.2 Il pannello non sparisce passandoci sopra con il mouse, e resta finché non premi un pulsante (al massimo 5 minuti).
- [ ] 2.3 Spegni "Le proposte di registrazione restano finché non rispondi": il pannello di esempio sparisce da solo dopo 30 secondi.
- [ ] 2.4 Crea una riunione di prova con link Teams che inizi tra 2 minuti. All'orario d'inizio compare **"Sta per iniziare «titolo»"**.
- [ ] 2.5 Crea due riunioni sovrapposte: compaiono due pannelli, uno sotto l'altro.
- [ ] 2.6 Premi **Registra**: la registrazione parte (l'icona di IAGO nella barra dei menu mostra il tempo).
- [ ] 2.7 Senza un evento in calendario, con IAGO fermo, entra in una call Teams: dopo circa 5 secondi compare **"Sei in una call Teams"**.
- [ ] 2.8 Esci dalla call mentre IAGO registra: dopo circa 30 secondi compare **"La call è finita"** con **Ferma**.
- [ ] 2.9 Il titolo dell'elemento registrato è quello della riunione del calendario, oppure "Call Teams del …" se non c'era un evento.

- [ ] 2.10 Con una riunione del Calendario in corso da più di 15 minuti, avvia un'altra call Teams: il pannello chiede **quale riunione** è (un pulsante per riunione più "Call Teams del …"). Il titolo scelto è quello dell'elemento.
- [ ] 2.11 Con due riunioni che iniziano alla stessa ora, entra in una: con l'Accessibilità attiva (sez. 3) IAGO sceglie da solo quella giusta; senza, chiede quale.

## 3. Microfono spento in Teams
- [ ] 3.1 Impostazioni › Audio › Riunioni › attiva **"Segui il mute di Teams con l'Accessibilità di macOS"** e consenti il permesso.
- [ ] 3.2 In una riunione Teams la riga di stato dice "Pulsante del microfono trovato" e cambia tra "in mute" e "microfono attivo" quando premi il pulsante in Teams.
- [ ] 3.3 Registra con un tratto in mute in cui parli: nella trascrizione quel tratto della tua voce non c'è.
- [ ] 3.4 (Solo se nella tua azienda è attiva) API locale di Teams: in Teams › Impostazioni › Privacy compare "API di app di terze parti"; attivala, poi in IAGO "Collega l'API locale di Teams" e consenti IAGO in una riunione.

## 3b. Microfono e app di call
- [ ] 3b.1 Durante una registrazione di IAGO il microfono di Teams funziona: gli altri ti sentono, anche in mute e dopo il mute.
- [ ] 3b.2 In Impostazioni › Audio c'è solo la scelta del microfono (nessuna opzione che tocchi il microfono dell'app di call).

## 3c. Attività
- [ ] 3c.1 Nella barra laterale, sotto Importa, c'è **Attività**. Con qualcosa in corso mostra un numero.
- [ ] 3c.2 Durante una registrazione, Attività mostra durata, microfono e, in mute su Teams, "silenzio sulla tua traccia". Pausa e Ferma funzionano.
- [ ] 3c.3 Avvia la trascrizione di due elementi: il primo è "In corso" con percentuale e tempo rimasto, il secondo "In coda". "Fai prima questo" e "Annulla" funzionano.
- [ ] 3c.4 Alla fine compaiono in "Ultime 24 ore". Una trascrizione annullata si può rifare con "Riprova"; "Apri" apre l'elemento.
- [ ] 3c.5 Importa un file, fai un backup ed esporta gli audio: ognuno compare mentre lavora e poi tra le ultime.

## 3d. Sintesi per categoria
- [ ] 3d.1 Impostazioni › Categorie: le principali (1to1, Kickoff, SAL, Workshop, Review/Demo, Client/Sales, Customer discovery, Interna, Altro) hanno ciascuna un modello di sintesi. Le famiglie Agile, Direzione, Persone e Operazioni sono spente.
- [ ] 3d.2 Accendi "Daily standup" (Agile): nella scheda di un elemento la categoria si sceglie da Agile › Daily standup.
- [ ] 3d.3 "Modifica il modello…": cambia una sezione e salva; la categoria mostra "(modificato)". "Ripristina l'originale" torna indietro. Esporta e reimporta il modello (JSON).
- [ ] 3d.4 Apri una call trascritta senza categoria: il blocco **Sintesi** dice "non ancora disponibile", con la scelta della categoria e "Genera sintesi".
- [ ] 3d.5 Scegli la categoria e premi Genera: compaiono avanzamento (anche in Attività) e poi la sintesi. Ogni minuto apre il lettore in quel punto.
- [ ] 3d.6 Le sezioni senza contenuto dicono "Non emerso". Le cifre della sintesi sono quelle dette nella call.
- [ ] 3d.7 Cambia categoria: compare "Rigenera con il modello «…»", ma la sintesi non cambia da sola. "Modifica…" e poi "Rigenera" chiede conferma.
- [ ] 3d.8 Registra una call nuova con la categoria già scelta: a fine trascrizione la sintesi arriva da sola, con una notifica.
- [ ] 3d.9 Cerca una parola della sintesi: compare tra i risultati come "Sintesi". La sintesi è anche nell'esportazione del progetto e in Obsidian.

## 3e. Barra laterale, categorie e tag
- [ ] 3e.1 La barra ha tre parti separate da linee sottili: le viste in alto (fisse), "Progetti" (l'unica che scorre, staccata dalle viste da uno spazio vuoto), una barra in fondo con "＋" e il cestino con il numero di elementi.
- [ ] 3e.2 I clienti si aprono e chiudono con un clic sull'intestazione, come in Teams (chiusi mostrano il numero di progetti). ⌥-clic apre solo quel cliente e chiude gli altri. Passando sopra compaiono "→" (apri il cliente) e "+" (nuovo progetto).
- [ ] 3e.2a Anche "In evidenza" (pin rosso) si apre e chiude con un clic.
- [ ] 3e.2b "Senza cliente" (quadratino grigio) è sempre l'ultima voce e contiene i progetti senza cliente e, in fondo, "Non definito". Con più di 15 progetti compare "Filtra progetti".
- [ ] 3e.3 "Categorie e tag" mostra le categorie con il numero di elementi e i tag; il clic apre l'elenco su tutti i progetti.
- [ ] 3e.4 Con il tasto destro su una categoria o un tag "Fissa in «In evidenza»": compare in cima alla barra laterale.
- [ ] 3e.5 Nel campo di ricerca scrivi `#` o `categoria:`: compaiono i tag o le categorie da aprire.
- [ ] 3e.7 Su un Mac senza IAGO (o con un archivio nuovo): al primo avvio la barra laterale mostra **Cliente Test** con **Pj. Test 1** (stream *Pj1 - Stream 1* e *Pj1 - Stream 2*) e **Pj. Test 2**; in "In evidenza" ci sono *Pj1 - Stream 1* e *Pj. Test 2*. Eliminato il cliente, l'esempio non ricompare al riavvio. Su un archivio già in uso non compare.
- [ ] 3e.8 Tasto destro su uno stream › **Fissa in alto**: compare in "In evidenza" con sotto il nome del progetto; **Togli dall'alto** lo toglie.
- [ ] 3e.6 Nella scheda di un elemento, il clic su un tag apre tutti gli elementi con quel tag. Accanto alla categoria non c'è nessuna icona: tutti gli elementi di una categoria si aprono da Categorie e tag.

## 3f. Aiuto, tour e glossario
- [ ] 3f.1 Al primo avvio dopo la configurazione compare il tour di benvenuto (7 pagine: memoria, registrazione con l'icona di IAGO, importazioni, decisioni e momenti, sintesi, Chiedi, dati sotto il tuo controllo). "Non mostrare più" lo spegne; si rivede da Aiuto › Primi passi.
- [ ] 3f.2 "Aiuto di IAGO" si apre dal menu della barra e dal "?" nella finestra; ogni argomento si legge e i pulsanti "Apri Impostazioni" funzionano.
- [ ] 3f.2b Il pulsante **? Guida** in alto a sinistra, accanto alle Impostazioni, apre la guida a tutta pagina: capitoli a sinistra, testi e immagini, ricerca, "← Precedente / Successivo →".
- [ ] 3f.2c Impostazioni › **Aiuto**: "Apri la guida", "Rivedi il tour di benvenuto" e "Mostra il tour all'avvio" funzionano.
- [ ] 3f.3 Impostazioni › Trascrizione › Glossario: scrivi un nome difficile detto in una call (es. un'azienda), ritrascrivi: il nome è scritto giusto.

## 3g. Aggiornamenti e motore minimo per le sintesi
- [ ] 3g.1 Impostazioni › Generale › Aggiornamenti mostra la versione installata; "Controlla ora" e la voce del menu "Controlla aggiornamenti…" aprono il controllo di Sparkle.
- [ ] 3g.2 Con una release minore pubblicata: IAGO la propone (installa, più tardi, salta) e dopo l'installazione si riapre con la nuova versione.
- [ ] 3g.3 Con una release maggiore pubblicata: IAGO non avvia nuove registrazioni finché non è installata ("Aggiornamento obbligatorio"); una registrazione in corso continua.
- [ ] 3g.4 Con Qwen 3.5 4B attivo, il blocco Sintesi dice che serve almeno il 9B e "Genera sintesi" porta a Impostazioni › Motore. Con il 9B o Gemma la sintesi si genera.
- [ ] 3g.5 Su un Mac da 16 GB, Impostazioni › Motore consiglia Qwen 3.5 9B.

## 3h. Barra di ascolto
- [ ] 3h.1 Apri una call con audio e premi Play: sotto la barra in alto compare la barra di ascolto con Cliente › Progetto › Stream › Elemento, i controlli, il tempo e la traccia.
- [ ] 3h.2 Passa ad Attività, a un altro progetto o a Punti chiave: l'audio continua e la barra resta. Pausa, 15 s indietro e avanti e la posizione funzionano.
- [ ] 3h.3 Un clic sul percorso riapre l'elemento che stai ascoltando.
- [ ] 3h.4 In pausa la barra resta; la **X** ferma l'audio e chiude la barra.
- [ ] 3h.5 Apri un altro elemento con audio mentre ascolti: l'audio non si interrompe; Play in quell'elemento passa al suo audio e la barra si aggiorna.
- [ ] 3h.6 Cambiando traccia (Mix, Solo microfono, Solo sistema) l'ascolto prosegue dallo stesso punto.
- [ ] 3h.7 Con una registrazione in corso le due barre stanno una sopra l'altra (registrazione sopra). Chiudere la finestra ferma l'audio.
- [ ] 3h.8 Un clic su un minuto della trascrizione o della sintesi fa partire l'audio da lì e apre la barra.

## 4. Ricerca per significato
- [ ] 4.1 Impostazioni › Motore › Ricerca per significato › **Scarica**. Il download finisce.
- [ ] 4.2 L'indicizzazione compare nella barra dei menu e finisce.
- [ ] 4.3 Cerca una frase con parole diverse da quelle usate in una call (es. "quanto versa l'azienda"): compaiono risultati "per significato".

## 5. Proposte automatiche
- [ ] 5.1 Apri una call trascritta › **"Cerca proposte"**: dopo circa un minuto compare la sezione Proposte.
- [ ] 5.2 **Conferma**, **Modifica…** e **Scarta** funzionano. Una proposta scartata non torna con "Cerca di nuovo".
- [ ] 5.3 Il segno "N proposte" compare in elenco e in timeline; Punti chiave › **Da confermare** le mostra.
- [ ] 5.4 Un elemento nuovo (registrato o importato) riceve proposte da solo, con notifica.

## 6. Chiedi a IAGO
- [ ] 6.1 Il pulsante **"Chiedi a IAGO"** in basso a destra apre il pannello. ⌘K fa lo stesso.
- [ ] 6.2 La X sul pulsante lo nasconde, e "Chiedi a IAGO" compare nella barra laterale sotto Importa.
- [ ] 6.3 Il pannello si chiude con la X e si ridimensiona trascinando il bordo sinistro (minimo 300 punti). La parte centrale si restringe e il testo va a capo.
- [ ] 6.4 Una domanda sul progetto dà una risposta con fonti numerate, che si aprono all'elemento e al minuto giusti.
- [ ] 6.5 "Conversazione temporanea": **Conserva** ed **Elimina** funzionano. Fissa e l'elenco delle conversazioni funzionano.
- [ ] 6.6 Aggiungi un elemento e riapri una conversazione: compare **"Nuovo materiale aggiunto"** con "Chiedi di nuovo".
- [ ] 6.7 "Salva come nota" mette la risposta nelle note del progetto.
- [ ] 6.8 Apri Chiedi da uno stream: la striscia **Contesto** mostra Cliente › Progetto › Stream (con il quadratino del cliente) e il campo dice "Chiedi su \<stream\>". Con nomi lunghi il percorso va a capo su due righe; passandoci sopra si legge tutto.
- [ ] 6.9 **Allarga contesto ▾** elenca progetto, cliente e Tutta la memoria, ognuno con il tipo sotto. Prima di chiedere, la scelta cambia solo il contesto.
- [ ] 6.10 Dopo una domanda, allarga: si apre una nuova conversazione nel contesto scelto con la stessa domanda; la precedente resta nell'elenco.
- [ ] 6.11 Da contesto allargato il link diventa **Cambia contesto ▾** e propone "Torna a" la sezione di partenza.
- [ ] 6.12 Una risposta senza fonti citate mostra sotto "Allarga contesto ▾". In Tutta la memoria il link non c'è.
- [ ] 6.13 Cambiando sezione nella barra laterale prima di chiedere, il contesto la segue.

## 7. Aggiungi a IAGO (Servizi)
- [ ] 7.1 Seleziona un testo in un'altra app › tasto destro › Servizi › **Aggiungi a IAGO**: il testo diventa un documento e IAGO lo apre.

## 8. Cartelle sorvegliate per le email
- [ ] 8.1 Impostazioni › Email e persone › **Aggiungi cartella**.
- [ ] 8.2 Un file `.eml` messo nella cartella viene importato entro un minuto, con una notifica riassuntiva.
- [ ] 8.3 Un invito a un meeting finisce in "Scartate". La stessa email messa due volte non entra due volte.
- [ ] 8.4 Una regola di esclusione e una di assegnazione funzionano.
- [ ] 8.5 "Sposta nella sottocartella «Importate»" e "Importa comunque" funzionano.

## 9. Claude (Claude Desktop)
- [ ] 9.1 Impostazioni › Claude: collega un progetto, attiva "Può scrivere" e riavvia Claude Desktop.
- [ ] 9.2 Chiedi a Claude di aggiungere una nota: prima mostra l'anteprima, poi scrive solo dopo il tuo OK. In IAGO la nota ha l'etichetta "tramite Claude (MCP)".
- [ ] 9.3 Chiedi a Claude di importare un PDF che hai in Download: lo trova da solo e lo importa con il testo.
- [ ] 9.4 Impostazioni › Claude › Annulla una modifica di Claude: la voce torna com'era.

## 10. Superamenti multipli (punti chiave)
- [ ] 10.1 Crea in un progetto una decisione, un'attività e una tappa. Poi crea una nuova tappa e, in **Supera**, aggiungi con "Aggiungi…" tutte e tre: diventano **Superate**.
- [ ] 10.2 Nel dettaglio della nuova tappa, Evoluzione mostra **"Supera:"** con le tre voci (cliccabili). Nel dettaglio di una di loro compare **"Superata da:"**.
- [ ] 10.3 Togli una voce con la ✕ e salva: quella voce torna **Attiva**.
- [ ] 10.4 Fai superare la stessa voce da due voci diverse. Annulla una delle due: la voce resta Superata. Annulla anche l'altra: torna Attiva.
- [ ] 10.5 Prova a far superare la voce più vecchia dalla più recente al contrario: IAGO chiede se cambiare l'ordine della catena.
- [ ] 10.6 Con Claude: "la firma del PX7 chiude la decisione X e le attività Y e Z". L'anteprima elenca tutte le voci che diventano Superate. Poi in Impostazioni › Claude **Annulla**: legami e stati tornano come prima.
- [ ] 10.7 Il grafo e l'esportazione del progetto mostrano tutti i legami.

## 10b. Importare JSON e incollare
- [ ] 10b.1 Trascina un file `.json` nella finestra: diventa un documento, con il JSON in ordine (un valore per riga).
- [ ] 10b.2 *Importa › Da testo*: incolla un JSON lungo su una riga sola e importa. Il titolo è "JSON incollato", il Mac resta reattivo e le proposte automatiche, se partono, finiscono senza bloccare nulla.
- [ ] 10b.3 Trascina un file `.csv` e uno `.yaml`: vengono importati come testo. Un file `.zip` mostra "Tipo di file non supportato".
- [ ] 10b.4 In una nota: **⌘V**, **⌘C**, **⌘X**, **⌘A** e **⌘Z** funzionano. Copia un file JSON nel Finder e incollalo nella nota con il tasto destro › *Incolla*: il suo testo entra nella nota, senza errori.
- [ ] 10b.5 Con la finestra aperta, in alto ci sono i menu IAGO, Modifica e Finestra; **⌘W** chiude la finestra, **⌘,** apre le Impostazioni.

## 10c. Coda del motore e memoria (Mac con 16 GB se possibile)
- [ ] 10c.1 Su un Mac con meno di 32 GB: Impostazioni › Motore › *Lavori automatici* mostra «Proponi automaticamente» e «Sintesi automatiche» spenti, con la riga che spiega perché. Su un Mac da 32 GB sono accesi.
- [ ] 10c.2 Con gli interruttori spenti, una call nuova trascritta non riceve né proposte né sintesi da sola; *Cerca proposte* e *Genera sintesi* funzionano.
- [ ] 10c.3 Avvia *Genera sintesi* su una call lunga e, mentre la scrive, fai una domanda in *Chiedi*: la risposta arriva senza aspettare la fine della sintesi, e poi la sintesi finisce comunque.
- [ ] 10c.4 Mentre una call si trascrive, fai una domanda in *Chiedi*: sotto i 32 GB la risposta arriva dopo la fine della trascrizione; il Mac resta reattivo.
- [ ] 10c.5 Su un Mac sotto i 24 GB: Gemma 4 12B mostra «Serve almeno 24 GB di memoria», e *Scarica* e *Usa questo* sono spenti.
- [ ] 10c.6 Monitoraggio Attività › Memoria durante una sintesi con Qwen 3.5 9B su 16 GB: la pressione di memoria non diventa rossa e nessuna app si chiude.

## 10d. Chi ha prodotto i risultati
- [ ] 10d.1 Sotto una sintesi: «Sintetizzata con Qwen 3.5 9B sul Mac» (o il modello usato).
- [ ] 10d.2 Ogni proposta mostra «Proposta da … sul Mac»; con Qwen 3.5 4B compare anche «modello piccolo», con la spiegazione al passaggio del mouse.
- [ ] 10d.3 Conferma una proposta di decisione e apri il punto chiave: dice «Proposto da … sul Mac, confermato da te».

## 10e. Segna momento con screenshot e scorciatoie
- [ ] 10e.1 Impostazioni › Permessi: la voce **Registrazione schermo** si attiva con *Consenti* (la prima volta macOS chiede, poi va in Impostazioni di Sistema).
- [ ] 10e.2 Durante una registrazione con una presentazione condivisa: **⌃⌥S** (anche mentre Teams è in primo piano). L'icona lampeggia; nella scheda, a fine call, la sezione **Schermate** mostra l'immagine al minuto giusto, senza finestre di IAGO.
- [ ] 10e.3 Nella trascrizione compare la riga «Schermata» con il testo letto; la ricerca di una parola della slide trova la call a quel minuto.
- [ ] 10e.4 *Genera sintesi*: se la slide contiene un fatto importante, un punto della sintesi può citarlo con il suo minuto.
- [ ] 10e.5 **⌃⌥M** segna un momento, **⌃⌥R** ferma la registrazione e la riavvia; senza registrazione ⌃⌥M e ⌃⌥S mostrano «Nessuna registrazione in corso».
- [ ] 10e.6 Impostazioni › Generale › *Scorciatoie in tutte le app*: cambia una combinazione, ripristina la predefinita, disattivala. Una combinazione già usata da un'altra app mostra «Usata da un'altra app».
- [ ] 10e.7 Apri una schermata ed **Elimina**: sparisce dalla scheda, dalla trascrizione e dalla ricerca.

## 10f. Claude fa sintesi e proposte
- [ ] 10f.1 Nella scheda di una call: **Copia per Claude… › Per la sintesi** con il progetto non consultabile: IAGO lo dice e offre di consentire lettura e scrittura; poi copia.
- [ ] 10f.2 Incolla in Claude Desktop: Claude mostra l'anteprima con i punti tenuti e scartati; dopo l'OK la sintesi compare con **«Sintetizzata da Claude»**.
- [ ] 10f.3 **Rigenera** chiede conferma prima di sostituire la sintesi di Claude.
- [ ] 10f.4 *Per le proposte*: le proposte compaiono come **«Consigliata da Claude»** e si confermano come quelle del motore.
- [ ] 10f.5 Chiedi a Claude «fai la sintesi della call di ieri»: trova l'elemento con gli elementi recenti, e se sono più d'uno chiede quale.
- [ ] 10f.6 Impostazioni › Claude › *Modifiche*: annulla la sintesi e le proposte di Claude.
- [ ] 10f.7 Con una call con schermate: senza «Condividi con Claude anche le immagini delle schermate» Claude legge solo il testo; attivandolo legge anche le immagini.

## 10g. Installazione da DMG e aggiornamenti
- [ ] 10g.1 Su un account utente o un Mac pulito: apri `IAGO-x.y.z.dmg`, trascina IAGO in Applicazioni; al primo avvio "Apri comunque" una sola volta.
- [ ] 10g.2 Aggiorna alla versione successiva con Sparkle: niente nuovo blocco, i permessi restano.
- [ ] 10g.3 Su una build compilata da sorgente, Impostazioni › Generale › Aggiornamenti dice che si aggiorna con git.

## 10h. Riconoscere le voci
- [ ] 10h.1 Impostazioni › Voci: l'interruttore è spento di default e la lista è vuota.
- [ ] 10h.2 Attivalo, registra o importa una call con almeno due persone dell'altra parte (ognuna parla più di 10 secondi) e rinomina "Speaker 1" con un nome inventato: la voce compare in Impostazioni › Voci con "1 call".
- [ ] 10h.3 Trascrivi una seconda call con la stessa persona: tra le proposte c'è «Speaker N diventa …» con «Riconosciuta dalla voce (somiglianza …%)». Conferma: il nome cambia e la voce sale a "2 call". Annota la percentuale, serve a tarare la soglia.
- [ ] 10h.4 Una persona diversa non riceve quel nome (se succede, annota la percentuale).
- [ ] 10h.5 Elimina la voce: un solo avviso, poi sparisce dalla lista. *Elimina tutte le voci…* chiede tre passaggi (avviso, DELETE, ultima conferma).
- [ ] 10h.6 Spegni l'interruttore: una nuova trascrizione non propone più nomi dalla voce.

## 10i. Lavoro aperto (1.1.0-beta e 1.2.0-beta)
Prima di tutto, se provi una build non ancora unita su `main`: `scripts/try-branch.sh` la apre su una copia dell'archivio. Per tornare indietro chiudi la prova e riapri IAGO.
- [ ] 10i.1 Apri un progetto per la prima volta: compare la finestra «… è in Modalità Gestisci» con le due modalità spiegate. *OK* la chiude e torna alla visita successiva; *Non mostrare più* la toglie per quel progetto. Il progetto si apre sul **Riepilogo**; accanto al nome c'è la pillola *Modalità Gestisci ▾* (blu, icona a colonne) e la stessa icona è accanto al progetto nella barra laterale. Dalla pillola scegli *Modalità Traccia* (verde, quaderno): spariscono la Kanban e il menu *Mostra*, il Riepilogo diventa breve. *Aggiungi* offre sempre la nota, i sei tipi e, in fondo, *Importa file ed elementi…*.
- [ ] 10i.2 Crea un'attività con responsabile (prova un nome simile a uno esistente: deve chiedere «Intendi …?»), scadenza di ieri e due righe di checklist: in timeline la scadenza è rossa e si vede 0/2.
- [ ] 10i.3 Scrivi qualcuno in *In attesa di* con una data: la voce passa *In attesa* e nell'**Inbox** compare sotto *Aspetto da altri*.
- [ ] 10i.4 In Gestisci *Segna come fatta*: ✓ verde, testo grigio non barrato; esce dall'Inbox e torna con *Mostra chiuse*. In Traccia l'attività ha una casella: spuntala dalla timeline, dal Riepilogo breve o dall'Inbox, poi togli la spunta (torna aperta).
- [ ] 10i.5 Punto da chiarire › *Chiarisci…* con *Diventa decisione*: nasce la decisione e il punto le sta sotto come «chiarito». Togli il legame dalla decisione: il punto torna aperto.
- [ ] 10i.6 Richiesta › *Accogli…* con due attività: nascono due attività «nate da» la richiesta, che risulta accolta. Un'altra richiesta › *Rifiuta…* con un motivo.
- [ ] 10i.7 In Gestisci: rischio con gravità alta › *Diventato problema*, poi *Risolto*. In Traccia lo stesso rischio non mostra gravità né *Diventato problema* (c'è l'icona dei dettagli di Gestisci) e si chiude con *Risolto*.
- [ ] 10i.8 Nella scheda di un'attività in Traccia c'è la casella *Fatta* al posto dello stato, con responsabile, scadenza, *In attesa di* e checklist; niente gravità né «nata da». Rimetti il progetto in *Gestisci*: compaiono gli stati, *Altri dettagli* (priorità, dipendenze, stima, inizio, ricorrenza) e la **Kanban**. Torna a *Traccia*: nessun dato perso, e un'icona segnala le voci con dettagli di Gestisci.
- [ ] 10i.9 In Gestisci: un'attività che *dipende da* un'altra aperta diventa Bloccata e si sblocca quando l'altra è fatta. Una dipendenza circolare è rifiutata con un messaggio chiaro.
- [ ] 10i.10 Attività ricorrente settimanale con scadenza: segnandola fatta nasce la successiva, una settimana dopo, con la checklist da rifare.
- [ ] 10i.11 Kanban di un progetto: occupa tutta la finestra, un clic su una scheda apre il pannello a destra (✕ o Esc lo chiudono). Trascina una scheda dalla colonna Da fare a In corso (cambia lo stato) e in In attesa (chiede da chi e fino a quando). Aggiungi la colonna «Da discutere» e trascinaci una scheda: lo stato non cambia.
- [ ] 10i.12 Colonna Fatta: con voci chiuse da più di 14 giorni compare «Attività chiuse 14+ giorni archiviate» con *Mostra tutte*; dopo il clic la riga diventa «Archivia attività chiuse 14+ giorni». Chiudi e riapri IAGO: la scelta è ricordata.
- [ ] 10i.13 Riepilogo in Gestisci: crea una checklist di progetto e fissala (compare nell'Inbox); *Sintesi di stato* scrive un testo dai punti chiave (compare in Attività) e si copia.
- [ ] 10i.14 Impostazioni › Progetti: la modalità di un progetto si cambia anche qui. Le attività di un progetto in *Traccia* sono nell'Inbox e nella **Kanban di tutti**, con l'icona del quaderno accanto al nome del progetto; spostane una in *In corso*: nel progetto resta da spuntare.
- [ ] 10i.15 Notifica del mattino accesa con l'ora tra due minuti e una voce che scade oggi: arriva la notifica con i conteggi e il clic apre l'Inbox.
- [ ] 10i.16 Trascrivi o importa una call in cui si fa una domanda senza risposta, si nomina un rischio, il cliente chiede qualcosa e qualcuno promette un invio «entro venerdì»: arrivano le proposte dei quattro tipi, con la frase d'origine, e la data di venerdì giusta.
- [ ] 10i.17 Con Claude Desktop: «elenca il lavoro aperto del progetto», «crea un'attività per Anna entro il 10 novembre con checklist…», poi annulla da Impostazioni › Claude.
- [ ] 10i.18 Barra delle viste: *Riepilogo* ed *Elementi*, ognuno a sé, poi Timeline · Kanban · Grafo, tutti con un'icona. *Elementi* mostra le call, le email e i documenti del progetto. *Mostra* (Tutto, Elementi, Punti chiave) compare solo con Timeline e Grafo; con la Kanban si legge «Mostra: Lavoro aperto». In Traccia la pillola ha *Mostra il Grafo*: spento, il Grafo sparisce dalla barra.
- [ ] 10i.19 Scegli Grafo in un progetto e Kanban in un altro, cambia progetto e torna: ognuno riapre l'ultima vista.
- [ ] 10i.20 Barra laterale: in cima **Inbox** in grassetto, con l'icona del vassoio e, se hai voci in ritardo o di oggi o proposte da confermare, il bollino rosso con il loro numero; sotto una linea e **Elementi da classificare**.
- [ ] 10i.21 *Aggiungi › Importa file ed elementi…* in un progetto: trascina un PDF nell'area, poi *Da testo* (si apre il campo) con un testo breve. Entrambi finiscono nel progetto, non in Elementi da classificare. *Email senza file* apre la finestra dell'email con il progetto già scelto.
- [ ] 10i.22 Apri un cliente per la prima volta: la finestra chiede la modalità dei suoi progetti. Scegli Traccia: i progetti a cui non avevi scelto una modalità passano in Traccia, e un progetto nuovo del cliente nasce in Traccia.
- [ ] 10i.23 Con il Riepilogo (o la Kanban) aperto, apri «Chiedi a IAGO»: la barra laterale resta al suo posto, con l'Inbox sotto i pulsanti della finestra. Nella Kanban apri una scheda: nel pannello a destra i pulsanti («Segna come fatta», «Modifica…») sono interi e la data sta sotto.

## 10l. Italiano e inglese (1.2.2-beta)
- [ ] 10l.1 Con un archivio nuovo (`scripts/try-branch.sh --fresh`), la prima schermata chiede «Lingua · Language». Scegli English: IAGO si riavvia in inglese e la configurazione riparte dal benvenuto, in inglese. L'esempio iniziale si chiama Test Client, Test Pj. 1 e Test Pj. 2.
- [ ] 10l.2 Impostazioni › Generale › Lingua: passa a Italiano. Compare «Riavviare IAGO?»; *Riavvia ora* riapre IAGO in italiano, con l'esempio iniziale e le categorie SAL, Interna e Altro di nuovo in italiano (se non li avevi rinominati).
- [ ] 10l.3 In inglese, la guida (? Guida) è in inglese, con le schermate in inglese.
- [ ] 10l.4 In inglese, genera la sintesi di una call e cerca le proposte: sintesi e proposte sono in inglese, con titoli inglesi («In brief»), mentre le citazioni restano come sono state dette.
- [ ] 10l.5 In inglese, nella ricerca `category:` suggerisce le categorie (anche `categoria:` funziona).
- [ ] 10l.6 Sito della documentazione: il selettore della lingua porta da ogni pagina alla stessa pagina in inglese, e il pulsante Uso/Tecnico resta nella lingua scelta.

## 11. Prove già in coda dalle fasi precedenti
- [ ] 11.1 "Riordina testo" su 2-3 note dettate: il testo resta fedele (nomi, numeri e date invariati).
- [ ] 11.2 Qualità della trascrizione su call reali con più persone.
- [ ] 11.3 Prove di accettazione delle Fasi 1-2 (registrazione di 2 ore, cuffie collegate e scollegate, sospensione del Mac, crash).
