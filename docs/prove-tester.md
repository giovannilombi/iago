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
- [ ] 3e.5 Premi **Cerca** (⌘F) e nella ricerca semplice scrivi `#` o `categoria:`: compaiono i tag o le categorie da aprire.
- [ ] 3e.7 Su un Mac senza IAGO (o con un archivio nuovo): finita la configurazione, la barra laterale mostra **Atoms**, **Poldo S.p.A.** e **Sanna TheBest s.r.l.** con i loro progetti, e *Portale clienti headless* in evidenza, pieno di call, email, documenti e punti chiave. *Impostazioni › Progetti › Rimuovi l'esempio* li toglie tutti e al riavvio non ricompaiono. Su un archivio già in uso non compaiono.
- [ ] 3e.8 Tasto destro su uno stream › **Fissa in alto**: compare in "In evidenza" con sotto il nome del progetto; **Togli dall'alto** lo toglie.
- [ ] 3e.6 Nella scheda di un elemento, il clic su un tag apre tutti gli elementi con quel tag. Accanto alla categoria non c'è nessuna icona: tutti gli elementi di una categoria si aprono da Categorie e tag.

## 3f. Aiuto, tour e glossario
- [ ] 3f.1 Al primo avvio dopo la configurazione compare l'introduzione (vedi 10s). "Non mostrare più" la spegne; si rivede da Aiuto › Primi passi.
- [ ] 3f.2 "Aiuto di IAGO" si apre dal menu della barra e dal "?" nella finestra; ogni argomento si legge e i pulsanti "Apri Impostazioni" funzionano.
- [ ] 3f.2b Il pulsante **? Guida** in alto a sinistra, accanto alle Impostazioni, apre la guida a tutta pagina: capitoli a sinistra, testi e immagini, ricerca, "← Precedente / Successivo →".
- [ ] 3f.2c Impostazioni › **Aiuto**: "Apri la guida", "Rivedi l'introduzione" e "Mostra l'introduzione all'avvio" funzionano.
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
- [ ] 6.9 **Cambia contesto ▾** propone *Aggiungi progetti…*, *Restringi contesto…*, *Contesto globale* e *Segui la sezione aperta*. Prima di chiedere, la scelta cambia solo il contesto.
- [ ] 6.10 Dopo una domanda, cambia contesto: si apre una nuova conversazione nel contesto scelto con la stessa domanda; la precedente resta nell'elenco.
- [ ] 6.11 Con un contesto scelto la striscia dice «Scelto da te: resta anche cambiando sezione»; *Segui la sezione aperta* la fa tornare alla sezione aperta.
- [ ] 6.12 Una risposta senza fonti citate: con **Cambia contesto ▾ › Contesto globale** la stessa domanda si ripete su tutta la memoria.
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
- [ ] 10i.20 Barra laterale: in cima **Inbox** in grassetto, con l'icona del vassoio e, se hai voci in ritardo o di oggi o proposte da confermare, i bollini con il loro numero (vedi 10n); sotto una linea e **Elementi da classificare**.
- [ ] 10i.21 *Aggiungi › Importa file ed elementi…* in un progetto: trascina un PDF nell'area, poi *Da testo* (si apre il campo) con un testo breve. Entrambi finiscono nel progetto, non in Elementi da classificare. *Email senza file* apre la finestra dell'email con il progetto già scelto.
- [ ] 10i.22 Apri un cliente per la prima volta: la finestra chiede la modalità dei suoi progetti. Scegli Traccia: i progetti a cui non avevi scelto una modalità passano in Traccia, e un progetto nuovo del cliente nasce in Traccia.
- [ ] 10i.23 Con il Riepilogo (o la Kanban) aperto, apri «Chiedi a IAGO»: la barra laterale resta al suo posto, con l'Inbox sotto i pulsanti della finestra. Nella Kanban apri una scheda: nel pannello a destra i pulsanti («Segna come fatta», «Modifica…») sono interi e la data sta sotto.

## 10l. Italiano e inglese (1.2.2-beta)
- [ ] 10l.1 Con un archivio nuovo (`scripts/try-branch.sh --fresh`), la prima schermata chiede «Lingua · Language». Scegli English: IAGO si riavvia in inglese e la configurazione riparte dal benvenuto, in inglese. I progetti di esempio sono in inglese (Headless customer portal…).
- [ ] 10l.2 Impostazioni › Generale › Lingua: passa a Italiano. Compare «Riavviare IAGO?»; *Riavvia ora* riapre IAGO in italiano, con l'esempio iniziale e le categorie SAL, Interna e Altro di nuovo in italiano (se non li avevi rinominati).
- [ ] 10l.3 In inglese, la guida (? Guida) è in inglese, con le schermate in inglese.
- [ ] 10l.4 In inglese, genera la sintesi di una call e cerca le proposte: sintesi e proposte sono in inglese, con titoli inglesi («In brief»), mentre le citazioni restano come sono state dette.
- [ ] 10l.5 In inglese, nella ricerca `category:` suggerisce le categorie (anche `categoria:` funziona).
- [ ] 10l.6 Sito della documentazione: il selettore della lingua porta da ogni pagina alla stessa pagina in inglese, e il pulsante Uso/Tecnico resta nella lingua scelta.

## 10m. Reattività della finestra e tag proposti (1.2.3-beta)
- [ ] 10m.1 Con IAGO aperto da qualche minuto e senza lavori in Attività, Monitoraggio Attività mostra IAGO vicino allo 0% di CPU (anche con Teams aperto e la lettura del mute di Teams attiva).
- [ ] 10m.2 La finestra di IAGO si trascina fluida come quella del Finder, e il passaggio tra Inbox, progetti e viste è immediato.
- [ ] 10m.3 Con la lettura del mute di Teams attiva, entra in una riunione di Teams: la call viene riconosciuta entro una ventina di secondi e il mute si legge come prima.
- [ ] 10m.4 Con alcuni tag già usati in altre call, registra una call su un altro tema e chiedi *Cerca proposte*: i tag proposti riguardano solo questa call, ognuno con la frase da cui viene (o una parola detta nella call); nessun tag delle altre call senza appiglio.

## 10n. Inbox con due bollini (1.2.4-beta)
- [ ] 10n.1 Con una voce tua in ritardo, una senza responsabile e qualche proposta da confermare: accanto a **Inbox** ci sono un bollino **rosso** con «!» e uno **giallo** con la stellina. Il passaggio del mouse su ciascuno dice cosa conta.
- [ ] 10n.2 Apri l'Inbox: il blocco **Da fare ora** ha nell'intestazione lo stesso numero rosso della barra laterale, e le sue righe (in ritardo, oggi, senza responsabile, attese scadute) sono esattamente quel numero.
- [ ] 10n.3 Il blocco **Proposte da confermare** ha lo stesso numero giallo e mostra le proposte per elemento, tre per elemento con *Mostra le altre*. *Conferma* su una proposta: il numero giallo scende di uno, nell'Inbox e nella barra laterale.
- [ ] 10n.4 *Scarta queste* su un elemento toglie solo le sue; *Scarta tutte…* chiede conferma e le toglie tutte. Il bollino giallo sparisce.
- [ ] 10n.5 Le voci di questa settimana, senza data e le attese non scadute stanno in **Più avanti**, con il numero grigio, e non entrano in nessun bollino.
- [ ] 10n.6 Apri una call con «Speaker 1» e scrivi un nome nel suo campo: il bordo diventa rosso, compaiono ⏎ e «Non salvato»; la trascrizione non cambia ancora. Passa a un altro elemento e torna: il testo è ancora lì, rosso. *Esc* lo annulla; *Invio* (o ⏎) lo salva e la trascrizione mostra il nome.
- [ ] 10n.7 Dai a uno speaker il nome «Antonello Prova», poi in un'altra call scrivi «Lello»: IAGO chiede se è «Antonello Prova». Rispondi *Sì*: lo speaker prende quel nome. In una terza call scrivi di nuovo «Lello»: propone subito «Antonello Prova». Con un nome senza somiglianze («Bruno Test») non chiede nulla.
- [ ] 10n.8 In una call con tre speaker dai a Speaker 3 lo stesso nome di Speaker 1: IAGO propone *Unisci*. Unisci: resta un campo, la trascrizione mostra quel nome anche sulle frasi di Speaker 3, e sotto c'è «Speaker 3 unito a …» con *Separa*. Rinomina Speaker 1: cambia anche sulle frasi di Speaker 3. *Separa*: Speaker 3 torna com'era.
- [ ] 10n.9 Su una call con speaker ancora «Speaker N» premi *Genera sintesi* (o *Rigenera*): IAGO chiede se dare prima i nomi. *Dai prima i nomi* apre la trascrizione con il cursore nel primo campo senza nome; *Procedi così* avvia la sintesi. Con tutti gli speaker con un nome la domanda non compare.

## 10o. Trascrizioni affiancate e consiglio Claude (1.2.5-beta)
- [ ] 10o.1 Su una call già trascritta da IAGO, *Allega trascrizione Teams…* con un `.vtt` di prova: compaiono le schede **★ IAGO** e **Teams**. Quella di IAGO resta la principale e i suoi minuti fanno partire l'audio.
- [ ] 10o.2 Nella scheda **Teams** i minuti sono testo grigio, senza link, e *Ascolta da qui* nel menu del clic destro è spento. Le schermate non compaiono tra le righe.
- [ ] 10o.3 Sulla scheda Teams *Rendi principale* (vedi 10p): le schede si scambiano. *Rigenera* la sintesi: usa il testo di Teams, e un clic su un minuto della sintesi non fa partire l'audio.
- [ ] 10o.4 *Elimina questa trascrizione…* sulla scheda Teams, con conferma: resta solo quella di IAGO e spariscono i nomi degli speaker di Teams. Ripeti con la trascrizione di IAGO: resta quella di Teams, che diventa principale.
- [ ] 10o.5 Su una call con solo la trascrizione di Teams, *Trascrivi*: IAGO trascrive e la sua trascrizione diventa la principale, con Teams accanto.
- [ ] 10o.6 Su un Mac da 16 GB o meno, in una call senza sintesi compare il consiglio «fai la sintesi con Claude». Su un progetto non consentito a Claude il pulsante è *Consenti e chiedi a Claude*. Senza collegamento a Claude è *Collega Claude…*, che apre Impostazioni › Claude.
- [ ] 10o.7 *Chiedi a Claude la sintesi*: la richiesta è negli appunti e Claude si apre. Incollala: Claude fa la sintesi, l'anteprima chiede l'OK e dopo la sintesi è nella scheda.
- [ ] 10o.8 *Usa il motore del Mac* su un progetto: il consiglio non compare più lì, ma sì sugli altri. In Impostazioni › Motore › *Sintesi e proposte* scegli **Claude**: i lavori automatici si spengono e il consiglio compare ovunque.

## 10p. Trascrizione principale e ricerca in tutte e due (1.2.6-beta)
Serve una call con la trascrizione di IAGO e quella di Teams (10o.1), e una parola che c'è solo in quella di Teams (per esempio un nome scritto in modo diverso).
- [ ] 10p.1 Nella sezione Trascrizione la prima scheda è **★ IAGO**. Aperta, sotto le schede c'è «★ Principale · usata per sintesi, proposte ed esportazioni». Sulla scheda **Teams** c'è invece *Rendi principale* con «Si cerca anche qui. Sintesi, proposte ed esportazioni usano «IAGO»».
- [ ] 10p.2 Cerca la parola che c'è solo in Teams: la call compare una volta, il passaggio dice «nella trascrizione Teams» e il suo minuto è grigio. Aprilo: si apre la scheda Teams e l'audio non parte.
- [ ] 10p.3 Cerca una parola che c'è in tutte e due: la call compare una volta, senza etichetta, e il passaggio apre la scheda IAGO con l'audio a quel punto.
- [ ] 10p.4 Con una sintesi già fatta, sulla scheda Teams *Rendi principale*: IAGO chiede conferma e ricorda che la sintesi resta com'è e che i minuti di Teams non sono collegati all'audio. Conferma: la ★ passa a Teams, che diventa la prima scheda, e sopra la sintesi compare «Fatta sulla trascrizione IAGO, ora la principale è Teams» con *Rigenera*.
- [ ] 10p.5 *Rigenera*: l'avviso sparisce e sotto la sintesi c'è «dalla trascrizione Teams». Ora cerca una parola che c'è solo nella trascrizione di IAGO: il passaggio dice «nella trascrizione IAGO».
- [ ] 10p.6 Su una call senza sintesi *Rendi principale* scambia subito, senza domande.

## 10q. Condividere un elemento (1.2.7-beta)
- [ ] 10q.1 Su una call trascritta con audio, *Condividi…*: l'elenco mostra Scheda, Trascrizione, Audio (con la dimensione) e, se ci sono, Tracce separate, Schermate, Altra trascrizione. Scheda e Trascrizione sono già spuntate.
- [ ] 10q.2 *Condividi…* con Scheda e Trascrizione: si apre il menu Condividi del Mac. Scegli Mail: il messaggio ha i due file `.md`. La scheda ha sintesi, punti chiave e note, senza trascrizione; la trascrizione ha i nomi degli speaker.
- [ ] 10q.3 Spunta anche Audio e *Un solo file .zip*, poi *Salva in una cartella…*: nella cartella c'è un solo `.zip` con la cartella dell'elemento e i tre file, e il Finder la mostra.
- [ ] 10q.4 Su un'email importata: le parti sono Scheda, Testo e Email originale (.eml); l'`.eml` si apre in Mail.
- [ ] 10q.5 Impostazioni › Privacy › registro accessi: c'è una riga di esportazione «share» per ogni condivisione. Mentre i file si preparano, la condivisione compare in Attività.

## 10r. Più persone nella stanza, presenti e aggiornamenti obbligatori (1.2.8-beta)
Servono due persone vere nella stessa stanza (nomi inventati nelle prove scritte).
- [ ] 10r.1 Senza nessuna call aperta, *Avvia registrazione* e parlate in due per almeno un minuto ciascuno. Trascrivi: chi ha parlato di più è «Io», l'altra voce è «Stanza 2», senza aver attivato nulla.
- [ ] 10r.2 Durante una call di prova con un'altra persona accanto a te, senza attivare nulla: dopo la trascrizione la voce accanto è sotto «Io» e nella scheda compare «Nel microfono ho sentito un'altra voce…» con *Separa le voci*. Premilo: la call viene ritrascritta e compare «Stanza 2».
- [ ] 10r.3 Durante una registrazione, menu dell'icona › *Più persone qui nella stanza* (resta spuntato). Dopo lo Stop il pannello ha *Più persone nella stanza* già attivo e la trascrizione separa le voci.
- [ ] 10r.4 Nel pannello dopo lo Stop scrivi in *Presenti* «Bruno Test, Carla Prova» e Invio: compaiono due nomi. Nella scheda, accanto a «Stanza 2», il pulsante dei presenti offre i due nomi; sceglierne uno rinomina lo speaker. Un nome già noto scritto in minuscolo prende la grafia nota.
- [ ] 10r.5 Con *Riconosci le voci* attivo, dai un nome a «Stanza 2»; in un'altra riunione con la stessa persona nella stanza arriva la proposta con quel nome.
- [ ] 10r.6 *Condividi* ed *Esporta*: la scheda Markdown riporta «Presenti: …».
- [ ] 10r.7 (Solo con una release di prova segnata obbligatoria) il menu dell'icona mostra «Aggiornamento obbligatorio …: installalo entro …» e *Aggiorna ora…*; dopo 2 giorni *Avvia registrazione* chiede di aggiornare e trascrizioni, sintesi e proposte non partono.

## 10s. Introduzione (1.2.9-beta)
- [ ] 10s.1 Con un archivio nuovo (`scripts/try-branch.sh --fresh` o un account utente di prova), finita la configurazione si apre l'introduzione: in alto «IAGO, sempre sulla tua spalla. Riunione dopo riunione.», dieci passi, «1 di 10».
- [ ] 10s.2 Ogni passo ha la sua schermata; il passo 2 ha le schede «Riconosce la riunione» e «Dopo lo Stop», il passo 5 Riepilogo, Timeline, Kanban e Grafo. In inglese le schermate sono quelle inglesi.
- [ ] 10s.3 I pulsanti portano nel punto giusto: progetto di esempio (sul passo 5 nella vista della scheda scelta), Importa, Inbox, Punti chiave, Chiedi a IAGO, Impostazioni › Claude e › Privacy, guida.
- [ ] 10s.4 Primi passi: importa un documento con l'introduzione aperta e la riga si spunta da sola; «x di 6 fatti» sale.
- [ ] 10s.5 Chiudi con *Inizia* senza *Non mostrare più*: al prossimo avvio si riapre. Con *Non mostrare più*, o con tutti i primi passi fatti, non si riapre; *Rivedi l'introduzione* in Aiuto › Primi passi e in Impostazioni › Aiuto la riapre.

## 10t. Dettaglio dell'elemento (1.2.11-beta)
- [ ] 10t.1 Apri una call: sotto il titolo cliente › progetto e data · durata · tipo, poi le tile. Ogni tile ha un solo dato; Trascrizione dice IAGO, Teams o IAGO + Teams; le tile delle sezioni vuote sono tratteggiate.
- [ ] 10t.2 Un clic su una tile apre la sezione (anche se era chiusa) e ci porta lì, con il titolo appena sotto la barra fissa.
- [ ] 10t.3 Scendi: compare la barra fissa (titolo, sotto cliente › progetto · data · durata, tile in miniatura) con evidenziata la sezione in cui sei; in basso a destra ↑ sopra «Chiedi a IAGO», senza sovrapporsi. Nascondi «Chiedi a IAGO» con la ✕: ↑ scende al suo posto. ↑ riporta in cima e barra e ↑ spariscono.
- [ ] 10t.4 Chiudi la Trascrizione in una call e lasciala aperta in un'altra: ognuna resta com'era. In Impostazioni › Generale › Dettaglio elemento metti Trascrizione su Chiusa: una call mai toccata la apre chiusa; *Riapplica a tutti gli elementi…* riporta tutte le call a questa scelta. File è sempre aperta.
- [ ] 10t.5 Una call senza segnalibri, note o collegamenti: quelle sezioni sono solo un'intestazione tratteggiata con la frase; *Aggiungi nota* e *Collega a…* funzionano da lì.
- [ ] 10t.6 Una call con segnalibri e schermate: tacche colorate sul player; sotto un momento alla volta con ‹ › e «N di M»; il minuto fa partire l'audio da lì; durante l'ascolto il momento segue l'audio. Gli stessi momenti sono nella trascrizione al loro minuto. Spegnendo le due caselle in Impostazioni spariscono.

## 10u. Riepilogo, Attività e correzioni (1.2.12-beta)
- [ ] 10u.1 Riepilogo di un progetto in Gestisci: box su due colonne senza buchi anche se un box ha molte più voci; le tile in alto restano visibili scorrendo; un clic su una tile porta al box e lo fa brillare, anche se è già in vista; i box vuoti sono un'intestazione tratteggiata; c'è *Ultime decisioni e tappe*.
- [ ] 10u.2 Un clic su una voce apre il pannello a destra e i box passano a una colonna; ✕ o Esc lo chiude e tornano due colonne. A finestra stretta una colonna e le tile vanno a capo, senza testi tagliati.
- [ ] 10u.3 Un progetto in Traccia: il Riepilogo breve ha subito il pannello a destra con il logo, senza ✕; aprendo una voce il pannello la mostra.
- [ ] 10u.4 Attività: a tutta finestra, nessun «Nessun elemento selezionato»; tile in alto che portano alle sezioni; *Ultimi 7 giorni* e *Pronto per lavorare* a destra (sotto con la finestra stretta); *Apri* mostra l'elemento nel pannello.
- [ ] 10u.5 Barra laterale: l'icona della modalità è verde (Traccia) o blu (Gestisci); un clic apre la scelta e cambiarla cambia il progetto. «Categorie e tag» si apre al clic.
- [ ] 10u.6 *Nuovo* in Punti chiave, con la finestra non a tutto schermo: il foglio si vede tutto, i tipi sono pillole su più righe, le etichette in una colonna.

## 10v. Stile, chiaro e scuro (1.2.13-beta)
- [ ] 10v.1 Accanto alle Impostazioni c'è il menu dell'aspetto: *Automatico* segue il Mac, *Chiaro* e *Scuro* cambiano subito tutte le finestre e restano dopo il riavvio.
- [ ] 10v.2 In chiaro non ci sono grandi zone bianche: pagine, liste (Recenti, Elementi da classificare), barre in alto e box sono grigi chiari; la barra laterale è più scura delle pagine.
- [ ] 10v.3 Titoli e testi sono neutri; il colore del tipo è nella barretta, nell'icona del box e nel puntino delle tile; nelle righe le icone sono grigie e diventano rosse solo per scaduto, bloccato o rischio alto. Sotto il titolo di ogni box c'è un filo sottile.
- [ ] 10v.4 *Aggiungi* in Punti chiave: il foglio dice «Aggiungi» e il tipo in una tile; un clic sulla tile cambia tipo; il menu ha i puntini e una linea tra decisioni/tappe e lavoro aperto.
- [ ] 10v.5 Una call con segnalibri e schermate: nella trascrizione stanno su un velo del loro colore con un filo a sinistra, la schermata con la miniatura.
- [ ] 10v.6 Kanban con colonne in box e la riga dello stato sotto il titolo; Attività in una colonna con *Ultimi 7 giorni* e *Pronto per lavorare* affiancati; Categorie e tag a tutta finestra.

## 10w. Inbox a due metà
- [ ] 10w.1 Con voci e proposte, *Da fare ora* occupa la metà alta e *Proposte da confermare* la metà bassa; ognuna scorre da sola e la barra si vede anche con «Mostra barre di scorrimento: automaticamente» nel Mac.
- [ ] 10w.2 Quando sotto ci sono altre voci, in basso a destra compare *altre N* con tre puntini che si accendono ogni 10 secondi circa; scorrendo fino in fondo sparisce.
- [ ] 10w.3 Confermate o scartate tutte le proposte, il box in basso si riduce all'intestazione e *Da fare ora* prende tutto lo spazio; *Più avanti* e *Mostra chiuse* stanno in fondo a *Da fare ora*.
- [ ] 10w.4 Trascinando la maniglia tra i due box cambia la loro altezza; chiudendo e riaprendo IAGO resta com'era; un doppio clic torna a metà e metà.
- [ ] 10w.5 Un clic sul box di un elemento in *Proposte da confermare* lo evidenzia e apre a destra tutte le sue proposte; *Conferma*, *Scarta*, *Conferma tutte* e *Scarta queste* aggiornano subito i numeri, e l'elemento senza più proposte esce dall'elenco. *Apri l'elemento* apre la sua scheda.
- [ ] 10w.6 Su un archivio dove non hai mai spostato il divisore, colonna centrale e destra sono a metà in ogni sezione. Allarga la colonna centrale in *Elementi da classificare*: in *Inbox* e in *Recenti* resta com'era, tornando in *Elementi da classificare* ritrovi la tua larghezza, anche dopo aver riavviato IAGO.
- [ ] 10w.7 Nella scheda di una call le sezioni sono, in ordine: Audio, Segnalibri, Schermate, Sintesi, Trascrizione, Proposte, Punti chiave, Note, Collegamenti, File; le tile in alto seguono lo stesso ordine.
- [ ] 10w.8 Trascina il titolo di *Note* (o la sua maniglia ≡) verso l'alto: tutte le sezioni si chiudono, in cima compare «Rilascia la sezione dove la vuoi…», *Note* è evidenziata e le altre si spostano mentre passi. Rilascia sopra *Sintesi*: *Note* resta lì, le sezioni tornano aperte o chiuse come prima e le tile si riordinano. Apri un'altra call e un'email: l'ordine è lo stesso, anche dopo aver riavviato IAGO. Rilasciando fuori dalla scheda il riordino si chiude da solo.
- [ ] 10w.9 *Impostazioni › Generale › Dettaglio elemento › Ripristina l'ordine delle sezioni* (attivo solo dopo un riordino) riporta l'ordine di base alla prossima scheda aperta.
- [ ] 10w.10 Barra laterale: niente titolo «Progetti»; a destra sopra *In evidenza* c'è *Aggiungi*, che apre *Aggiungi:* con *Cliente…* e *Progetto…*, e funzionano tutti e due. In fondo c'è solo *Cestino*, come le voci in alto, e un clic lo apre.
- [ ] 10w.11 Passando su un cliente compare solo **+**: apre *Nuovo progetto* con quel cliente scritto e non modificabile, e il progetto creato finisce sotto quel cliente. Dal tasto destro di un progetto, *Nuovo stream…* apre la sua finestra.
- [ ] 10w.12 Con la barra laterale stretta, resta due secondi sul nome troncato di un progetto: compare il nome intero, sparisce uscendo, e il clic sulla riga apre comunque il progetto.
- [ ] 10w.13 La linea tra colonna centrale e destra si ferma sotto la barra degli strumenti: in alto c'è solo la linea della barra laterale, in chiaro e in scuro.

## 10x. Categorie e tag, contesto, ricerca, microfono, voci e Claude (1.2.15-beta)
- [ ] 10x.1 *Categorie e tag*: tre colonne (etichette, elementi, dettaglio). A sinistra i riquadri *Categorie* e *Tag* si chiudono e si riaprono; nella ricerca dei tag Invio aggiunge il primo trovato. Scegli una categoria e due tag: al centro restano solo gli elementi con la categoria e **tutti e due** i tag; ✕ su un tag lo toglie, *Azzera* toglie tutto. Tasto destro su un tag: lo metti *In evidenza*.
- [ ] 10x.2 Trascina le due maniglie tra le colonne: le larghezze restano dopo il riavvio di IAGO; un doppio clic su una maniglia torna alle larghezze iniziali.
- [ ] 10x.3 *Chiedi a IAGO* da un progetto: il contesto è il progetto e dice «Segue la sezione aperta». *Cambia contesto › Aggiungi progetti…*: spunta un secondo progetto (anche con la casella del cliente) e *Applica*: compaiono due chip, la conversazione riparte con l'ultima domanda e le fonti vengono da tutti e due. Il contesto ora dice «Scelto da te» e resta cambiando sezione e riavviando IAGO.
- [ ] 10x.4 ✕ su un chip toglie quel progetto; *Restringi contesto…* lascia solo i progetti spuntati (spento con un solo progetto); *Contesto globale* passa a tutta la memoria; *Segui la sezione aperta* torna al comportamento di base.
- [ ] 10x.5 In alto a destra c'è *Cerca*, non più il campo: un clic o ⌘F apre *Ricerca semplice* nella spalla destra con la spiegazione, il cursore nel campo e la ✕ (anche Esc) per chiuderla. Cerca una parola: i risultati restano nella spalla e un clic apre l'elemento nella scheda accanto. `#` e `categoria:` mostrano i suggerimenti.
- [ ] 10x.6 Dalla ricerca, *Chiedi a IAGO* in fondo passa alla chat nella stessa spalla; nella chat la lente torna alla ricerca. Mentre una delle due spalle è aperta, il pulsante tondo *Chiedi a IAGO* in basso a destra sparisce.
- [ ] 10x.7 Nella chat, il pulsante *A tutta finestra*: restano la barra laterale, l'elenco delle conversazioni e la conversazione al centro; una fonte si apre a destra con la sua ✕. *Riduci a pannello* torna com'era, con la stessa conversazione. Un clic su una sezione della barra laterale esce dalla vista a tutta finestra. Chiudendo e riaprendo la chat la conversazione è ancora lì.
- [ ] 10x.8 Barra laterale: un clic sull'icona della modalità di un progetto apre la scelta; le spiegazioni di Traccia e Gestisci si leggono intere, senza puntini.
- [ ] 10x.9 Registra una call di prova e, durante la registrazione, stacca il microfono (o scegli in Impostazioni di Sistema un ingresso che non manda audio): entro 2-3 secondi il pallino dell'icona di IAGO diventa giallo, compare il pannello *Il microfono non registra* e il menu dice *Nessun audio dal microfono*. Ricollegalo: torna rosso e il pannello sparisce. *Ignora* chiude il pannello, che non torna finché il microfono non riprende e si ferma di nuovo; *Scegli il microfono* apre Impostazioni › Audio.
- [ ] 10x.10 Durante una registrazione resta in silenzio per più di 30 secondi mentre dall'audio del Mac c'è qualcuno che parla: il pallino resta rosso, compare una sola volta il pannello *Il microfono non sente la tua voce* e il menu ha la riga della traccia muta.
- [ ] 10x.11 Su un archivio nuovo Impostazioni › Voci ha *Riconosci le voci* acceso, e in cima *Il tuo nome*. Cambia il nome e premi Invio (o esci dal campo): sotto compare quante call sono state aggiornate, e in quelle call la tua voce ha il nome nuovo.
- [ ] 10x.12 In una call trascritta, scrivi nel campo di uno speaker le prime lettere di un nome già usato: compare l'elenco dei nomi noti; sceglierne uno e premere Invio, il ✓ o cliccare altrove salva il nome, senza bordo rosso. In una call trascritta prima di attivare le voci, sotto i nomi una riga dice di usare *Ritrascrivi*. Dopo *Ritrascrivi* e il nome dato, la voce compare in *Voci conosciute*.
- [ ] 10x.13 Accanto alla tua voce compare **Tu**, nella trascrizione e nei nomi: passandoci sopra, in una call registrata dice che è la voce del microfono registrata con IAGO; in un file audio importato, dopo aver dato a uno speaker il tuo nome, dice che è un file importato con il tuo nome.
- [ ] 10x.14 Un elemento senza sintesi, su un Mac con più di 16 GB: in fondo alla Sintesi, dopo *Genera sintesi*, c'è *Alternativa: fai la sintesi con Claude* in colori neutri, con i quattro passi (progetto, collegamento, consenso, richiesta) e il segno di fatto su quelli già a posto. Su un progetto già in Claude (icona di Claude nella barra laterale) il passo 3 dice che è già a posto. Ogni *come?* apre la guida al capitolo Claude.
- [ ] 10x.15 *Non mostrare più*: resta una striscia «Alternativa: puoi fare la sintesi anche con Claude.» con *Vedi come*, che riapre il riquadro per quell'elemento; aprendo un altro elemento torna la striscia.
- [ ] 10x.16 Con Claude Desktop aperto, rendi consultabile da Claude un progetto (Impostazioni › Claude, o *Consenti* nel riquadro): compare *Riavvia Claude Desktop*; *Riavvia Claude* chiude e riapre Claude Desktop, che poi vede il progetto. Con Claude Desktop chiuso l'avviso non compare.

## 10y. DMG e istruzioni di installazione (ADR-0097)
Da fare su un Mac o un account utente dove IAGO non è mai stato installato, con il DMG scaricato dalla release (non copiato da un altro Mac).
- [ ] 10y.1 Apri `IAGO.dmg`: la finestra ha lo sfondo con «Trascina IAGO in Applicazioni», IAGO a sinistra e Applicazioni a destra, con le tre frecce colorate in mezzo; in basso, nella fascia gialla, c'è *Leggimi - Read me*. Ripeti con il Mac in modalità scura e controlla che i nomi delle icone si leggano.
- [ ] 10y.2 Apri *Leggimi - Read me*: è nella lingua del Mac e il pulsante in alto passa da italiano a inglese. *Mostrami i passi* porta ai quattro passi, *Allergico ai menu?* porta al comando; *Copia* copia il comando.
- [ ] 10y.3 Trascina IAGO in Applicazioni e aprilo: compare l'avviso. Segui i passi di *Privacy e sicurezza › Apri comunque*: IAGO si apre e le volte successive si apre senza avviso.
- [ ] 10y.4 Su un altro account o Mac pulito, dopo aver trascinato IAGO, usa invece il comando del Terminale: chiede la password, e poi IAGO si apre senza avviso.
- [ ] 10y.5 Il link «Scarica IAGO.dmg» in cima al README scarica l'ultima versione.
- [ ] 10y.6 Su un Mac pulito, dopo il download: `xattr -d com.apple.quarantine ~/Downloads/IAGO.dmg` nel Terminale (senza password), poi il DMG si apre; IAGO trascinato in Applicazioni si apre senza nessun avviso. *Leggimi - Read me* si apre con il suo contenuto, non bianco.

## 10z. Modalità Raccogli (ADR-0098)
- [ ] 10z.1 Clic sull'icona della modalità di un progetto: le schede sono tre, Raccogli (scatola arancione), Traccia e Gestisci. Scegli Raccogli: nella barra laterale l'icona diventa la scatola.
- [ ] 10z.2 Nel progetto in Raccogli ci sono solo *Elementi* e *Timeline*, senza *Mostra*; la Timeline mostra solo gli elementi. *Aggiungi* offre la nota e l'importazione, non i punti chiave.
- [ ] 10z.3 In una call del progetto: segnalibri e schermate ci sono, anche nella trascrizione, ma senza *Diventa decisione…*; nella scheda non c'è *Punti chiave*. *Cerca proposte* propone nomi, tag e collegamenti, nessuna decisione o attività.
- [ ] 10z.4 Inbox: compare la riga «Dai progetti in Modalità Raccogli qui arrivano solo le proposte da confermare»; le proposte di quelle call ci sono, il loro lavoro aperto no.
- [ ] 10z.5 Su un Mac con 16 GB o meno e le sintesi automatiche accese, una call nuova del progetto non ha la sintesi da sola; *Genera sintesi* la scrive.
- [ ] 10z.6 Rimetti il progetto in Gestisci: i punti chiave scritti prima tornano visibili.
- [ ] 10z.7 Da Claude, chiedi di aggiungere una decisione al progetto in Raccogli: lo strumento rifiuta e spiega come cambiare modalità.

## 10za. Eliminare progetti, clienti e stream (ADR-0099)
Su un archivio di prova, con un progetto che ha due stream, qualche elemento, una nota e un punto chiave.
- [ ] 10za.1 Tasto destro sul progetto › *Elimina progetto…*: il dialogo dice quanti elementi, trascrizioni e note contiene ed elenca i due stream. *Sposta nel Cestino* è già scelto e ha la spiegazione.
- [ ] 10za.2 *Sposta nel Cestino*: il progetto e i suoi stream spariscono dalla barra laterale; i suoi elementi non compaiono in Recenti, la ricerca di una parola della nota non trova nulla, il punto chiave non è in Inbox né in Punti chiave. Il numero accanto a *Cestino* sale di uno.
- [ ] 10za.3 Nel Cestino, sezione *Progetti*: c'è il progetto con «eliminato tra 30 giorni». *Ripristina*: il progetto torna com'era, con stream, elementi, nota e punto chiave, e nello stesso cliente.
- [ ] 10za.4 Di nuovo *Elimina progetto…*, scegli *Elimina definitivamente* › *Continua*: chiede di scrivere DELETE (OK resta spento finché non è scritto), poi l'ultima conferma. Il progetto non è nel Cestino.
- [ ] 10za.5 Lo stesso da Impostazioni › Progetti › *Elimina…*: stesso dialogo.
- [ ] 10za.6 Tasto destro su un cliente con progetti › *Elimina cliente…*: elenca i progetti con i loro stream. Conferma: i progetti sono in «Senza cliente», con tutto il loro contenuto.
- [ ] 10za.7 Tasto destro su uno stream › *Elimina stream…*: dice quanti elementi, punti chiave e note perdono l'etichetta; dopo, restano nel progetto.
- [ ] 10za.8 Metti nel Cestino un elemento del progetto, poi il progetto; ripristina solo l'elemento: torna in *Elementi da classificare*.

## 11. Prove già in coda dalle fasi precedenti
- [ ] 11.1 "Riordina testo" su 2-3 note dettate: il testo resta fedele (nomi, numeri e date invariati).
- [ ] 11.2 Qualità della trascrizione su call reali con più persone.
- [ ] 11.3 Prove di accettazione delle Fasi 1-2 (registrazione di 2 ore, cuffie collegate e scollegate, sospensione del Mac, crash).
