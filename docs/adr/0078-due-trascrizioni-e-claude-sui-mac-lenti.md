# ADR-0078 — Trascrizioni di IAGO e di Teams affiancate, Claude consigliato sui Mac lenti

- Stato: accettato (1.2.5-beta), modificato nella 1.2.6-beta e da ADR-0095 (Claude su ogni Mac)
- Data: 2026-10-30
- Riferimenti: ADR-0033 (trascrizioni Teams), ADR-0043 (server MCP), ADR-0054 (sintesi), ADR-0069 (coda unica e memoria), ADR-0071 (sintesi e proposte fatte da Claude), ADR-0058 (niente esce senza la scelta dell'utente); richieste dell'utente del 2026-10-30

## Contesto
- Allegare la trascrizione di Teams **sostituiva** quella di IAGO, con due perdite:
  - i minuti di Teams contano dall'avvio della trascrizione di Teams, non della registrazione, quindi i link all'audio portavano nel punto sbagliato;
  - la trascrizione di IAGO, con le due tracce e le voci, spariva.
- L'utente vuole entrambe, affiancate, sempre per sua scelta, e la possibilità di eliminare l'una o l'altra anche dopo.
- Sui Mac fino a 16 GB sintesi e proposte con il motore locale sono lente. Claude le può fare con gli stessi controlli (ADR-0071), ma l'utente non lo scopre se nessuno glielo dice.
- Trascrivere con Claude è escluso: i modelli Claude non leggono l'audio.

## Decisione
- **Due trascrizioni affiancate:**
  - una call può avere la trascrizione di IAGO e quella di Teams insieme. Quella principale è l'asset `transcript_json`, l'altra `alternate_transcript_json`. Nessuna migrazione: i tipi di asset sono testo;
  - *Allega trascrizione Teams…* **aggiunge**: se la call ha la trascrizione di IAGO, quella resta principale e Teams si affianca. Un'altra trascrizione di Teams sostituisce solo quella di Teams;
  - *Trascrivi* su una call che ha solo Teams sposta Teams di fianco e mette davanti quella di IAGO, che ha i minuti legati all'audio;
  - nella scheda ci sono le schede **IAGO**, **Teams** e Markdown. I minuti di Teams sono solo testo (`Transcript.isImported`): niente link all'audio, niente «Ascolta da qui», niente schermate al loro minuto. Lo stesso vale per sintesi, punti chiave e risultati di ricerca di una call la cui trascrizione principale è di Teams;
  - **la principale è una sola**: sintesi, proposte, ricerca, esportazioni e Claude leggono quella, così nessuna frase conta due volte. *Usa questa per sintesi, proposte e ricerca* le scambia (`Archive.swapTranscripts`): entrambe vengono riscritte nel proprio file, così una nuova trascrizione non sovrascrive mai l'altra. Una sintesi già fatta non cambia da sola;
  - *Elimina questa trascrizione…* toglie una delle due, per sempre, dopo conferma. Resta l'altra, che diventa la principale. Se ne vanno con lei i suoi speaker e, per Teams, il file originale (`Archive.removeTranscript`);
  - i nomi degli speaker di Teams restano come li scrive Teams. Abbinarli agli speaker di IAGO richiede di allineare i tempi delle due trascrizioni: è un passo successivo, non in questo ADR.
- **Consiglio «Usa Claude»:**
  - sui Mac fino a 16 GB, sotto *Sintesi* e *Proposte*, un riquadro consiglia Claude: *Chiedi a Claude la sintesi* copia la richiesta di ADR-0071 e apre l'app Claude, e l'utente la incolla. IAGO non può mandare un lavoro a Claude da solo, perché con MCP è sempre Claude a chiamare IAGO;
  - **niente si abilita da solo.** Il riquadro dice cosa manca e offre il passo, sempre con un clic dell'utente:
    - nessun collegamento a IAGO nella configurazione di Claude Desktop: *Collega Claude…* apre Impostazioni › Claude;
    - collegamenti limitati ad altri progetti (`--project`, `--client`): va aggiunto un collegamento che includa questo;
    - progetto non consultabile o non scrivibile: *Consenti e chiedi a Claude* lo abilita solo per quel progetto;
    - elemento senza progetto: va assegnato prima, perché Claude scrive solo nei progetti;
  - ogni risultato passa dall'anteprima e dall'OK dell'utente, come sempre (ADR-0047). «Compare qui» vuol dire che dopo l'OK la sintesi è nella scheda;
  - *Usa il motore del Mac* nasconde il consiglio su quel progetto per sempre (impostazione dell'archivio `claudeTip.declinedProjects`); *Non mostrare più* lo nasconde su quel Mac;
  - **Impostazioni › Motore › Sintesi e proposte: Motore del Mac / Claude** (`intelligence.byClaude`). Con Claude il motore del Mac non parte più da solo, i lavori automatici sono spenti e il consiglio compare su qualsiasi Mac.
- I collegamenti di Claude Code non si leggono: IAGO non ha un file sicuro dove trovarli. Chi usa solo Claude Code vede «Collega Claude…», ma può comunque copiare la richiesta da *Copia per Claude…*.

## Modifica (1.2.6-beta, 2026-10-30)
Richiesta dell'utente: la ricerca deve guardare anche nella trascrizione secondaria, e la principale deve vedersi.
- **Ricerca in tutte e due:** anche la trascrizione secondaria è nell'indice. Una call compare una volta: i passaggi della secondaria contano solo se la principale non ha le stesse parole, con l'etichetta «nella trascrizione Teams» (o IAGO), e aprono quella scheda. La ricerca per significato e Claude restano sulla principale.
- **La principale si vede:** ★ accanto al nome della sua scheda, sempre la prima, e sotto «Principale · usata per sintesi, proposte ed esportazioni». Sull'altra *Rendi principale*, con conferma se la call ha già una sintesi.
- **Sintesi e trascrizione:** la sintesi ricorda da quale trascrizione è stata scritta (`summary.transcript_source`, migrazione `v23-summary-transcript`). Se la principale cambia, sopra la sintesi compare «Fatta sulla trascrizione IAGO, ora la principale è Teams» con *Rigenera*; non si rigenera da sola.

## Conseguenze
- Esportazioni, sintesi, proposte e Claude contengono solo la trascrizione principale. La ricerca, dalla 1.2.6-beta, guarda in tutte e due.
- Le call di prima con Teams al posto di IAGO sono riconosciute dal motore della trascrizione salvata (`asr = teams`): i loro minuti smettono di essere link all'audio.
- Il consiglio prepara il terreno per altri assistenti (ADR-0079): oggi nomina Claude, domani l'assistente scelto.
