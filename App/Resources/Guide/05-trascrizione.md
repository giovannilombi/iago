<!-- icona: text.bubble -->
# Trascrizione

La trascrizione avviene sul Mac. Due motori:

| Motore | Pro | Contro |
| --- | --- | --- |
| Whisper large-v3-turbo | più preciso sull'italiano | più lento |
| Parakeet | circa 4 volte più veloce | meno preciso sui nomi |

## Chi parla
La tua traccia è **Io** (il nome che hai dato all'inizio). Le voci degli altri vengono separate per persona ("Speaker 1", "Speaker 2"…). **Rinomina gli speaker** nella scheda, nel campo accanto a *Speaker:*.
- Il nome si salva con **Invio** o con il pulsante **⏎** accanto al campo, e solo allora cambia nella trascrizione. Finché non lo salvi il campo ha il **bordo rosso**: il testo resta lì anche se passi a un altro elemento, ed **Esc** lo annulla.
- **Nomi simili:** se esiste già un nome simile, IAGO chiede se è la stessa persona, per esempio «Esiste già *Antonello*. *Lello* è la stessa persona?». Riconosce i nomi scritti in modo diverso (*Marco* e *Marco Rossi*), gli errori di battitura e i diminutivi più comuni (*Lello* e *Antonello*, *Peppe* e *Giuseppe*). Se rispondi di sì usa il nome già noto e se lo ricorda: la volta dopo lo propone subito, anche per i soprannomi che non conosceva.
- **Stesso nome a due speaker:** a volte la stessa voce viene divisa in due. Se dai a uno speaker il nome di un altro della stessa call, IAGO propone di **unirli**: resta un solo speaker, con tutte le sue frasi. Sotto i campi compare «Speaker 3 unito ad Antonello» con **Separa**, che lo riporta com'era.
- I nomi valgono per le esportazioni e per ciò che il motore scrive da lì in poi. Una sintesi già fatta resta com'è: *Rigenera* la riscrive con i nomi nuovi.
- **Prima della sintesi:** se chiedi *Genera sintesi* o *Rigenera* e qualche speaker si chiama ancora «Speaker 1», IAGO chiede se vuoi **dare prima i nomi** (ti porta ai campi) o **procedere così**. La sintesi si può sempre rigenerare più avanti. Le sintesi automatiche non chiedono.

Il motore locale può anche proporre i nomi.

## Più persone nella stanza
Le persone collegate da remoto si separano sempre, anche se sono in tanti dallo stesso computer. Per chi è nella stanza con te:
- **Riunione in presenza** (l'audio del Mac è muto): IAGO separa da solo le voci del microfono. Tu resti «Io», gli altri diventano «Stanza 2», «Stanza 3»…
- **Call con qualcuno accanto a te:** IAGO non separa da solo, perché il microfono sente anche l'eco della call. Se sente altre voci oltre alla tua, nella scheda compare «Nel microfono ho sentito altre voci» con **Separa le voci**, che ritrascrive la call.
- Puoi deciderlo anche prima: **Più persone qui nella stanza** dal menu durante la registrazione, oppure **Più persone nella stanza** quando trascrivi.
- **Presenti:** nella scheda, e nel pannello dopo lo Stop, scrivi chi c'era (un nome e Invio, o più nomi separati da virgole). Accanto a ogni speaker ancora senza nome compare un pulsante per sceglierlo tra i presenti. I presenti finiscono anche nelle esportazioni e in *Condividi*.

## Riconoscere le voci
In **Impostazioni › Voci** puoi attivare *Riconosci le voci tra una call e l'altra* (spento di default). Quando dai un nome a uno speaker, IAGO ricorda la sua voce; nelle call successive propone il nome («Speaker 2 diventa Marco», *Riconosciuta dalla voce*) e tu confermi o scarti. Non assegna mai un nome da solo.

- Vale per le call trascritte dopo l'attivazione; per una call già trascritta usa **Ritrascrivi**.
- Servono almeno una decina di secondi di parlato per riconoscere una voce.
- Valgono anche le voci della stanza, quando sono separate. La tua («Io») no.
- Le voci restano solo sul Mac e non vanno mai a Claude né nelle esportazioni. Nello stesso pannello vedi le voci conosciute e le elimini una per una o tutte insieme.

## Glossario
In **Impostazioni › Trascrizione › Glossario** scrivi nomi e sigle che vanno scritti giusti (aziende, prodotti, persone), separati da virgole. Per ogni call IAGO aggiunge da solo progetto, cliente, stream e contatti. Vale per Whisper e aiuta su molti nomi, non su tutti.

## Dopo lo Stop
In Impostazioni › Trascrizione scegli cosa succede a fine registrazione: **trascrivi subito**, **chiedi**, oppure **trascrivi e cancella l'audio** (l'audio viene eliminato solo dopo aver verificato la trascrizione). Puoi anche trascrivere solo quando il Mac è collegato alla corrente.

## Correggere
Puoi ritrascrivere con l'altro motore, rinominare gli speaker, e per documenti ed email correggere il testo a mano (il testo automatico resta ripristinabile). Una trascrizione di Teams (.vtt o .docx) si può allegare a una registrazione.

## Trascrizione di IAGO e di Teams
Una call può avere **due trascrizioni affiancate**: quella di IAGO e quella di Teams. *Allega trascrizione Teams…* la **aggiunge**, non sostituisce quella di IAGO. Allo stesso modo, *Trascrivi* su una call che ha solo Teams aggiunge quella di IAGO.
- Nella sezione Trascrizione ci sono due schede, **IAGO** e **Teams**, oltre a Markdown.
- Nella trascrizione di IAGO un minuto fa partire l'audio da lì. In quella di Teams i minuti sono **solo testo**: Teams li conta dall'avvio della sua trascrizione, non della registrazione, e non corrispondono all'audio.
- Una delle due è la **principale**, con la ★ accanto al nome della scheda: è sempre la prima, e di solito è quella di IAGO. Sintesi, proposte, esportazioni e Claude usano la principale. La **ricerca** guarda in tutte e due.
- Per cambiarla apri la scheda dell'altra e premi **Rendi principale**. Se la call ha già una sintesi, IAGO chiede conferma: la sintesi resta com'è finché non la rigeneri, e sopra compare «Fatta sulla trascrizione IAGO, ora la principale è Teams» con *Rigenera*.
- *Elimina questa trascrizione…* toglie una delle due, anche dopo. Resta l'altra. Non si può annullare, ma la trascrizione si può rifare o allegare di nuovo.
- Allegare un'altra trascrizione di Teams sostituisce quella di Teams di prima, mai quella di IAGO.
