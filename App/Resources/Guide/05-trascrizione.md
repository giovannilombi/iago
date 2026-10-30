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

Con più persone nella stessa stanza attiva **Più persone nella stanza** quando trascrivi: IAGO separa anche le voci della tua traccia.

## Riconoscere le voci
In **Impostazioni › Voci** puoi attivare *Riconosci le voci tra una call e l'altra* (spento di default). Quando dai un nome a uno speaker, IAGO ricorda la sua voce; nelle call successive propone il nome («Speaker 2 diventa Marco», *Riconosciuta dalla voce*) e tu confermi o scarti. Non assegna mai un nome da solo.

- Vale per le call trascritte dopo l'attivazione; per una call già trascritta usa **Ritrascrivi**.
- Servono almeno una decina di secondi di parlato per riconoscere una voce.
- Le voci restano solo sul Mac e non vanno mai a Claude né nelle esportazioni. Nello stesso pannello vedi le voci conosciute e le elimini una per una o tutte insieme.

## Glossario
In **Impostazioni › Trascrizione › Glossario** scrivi nomi e sigle che vanno scritti giusti (aziende, prodotti, persone), separati da virgole. Per ogni call IAGO aggiunge da solo progetto, cliente, stream e contatti. Vale per Whisper e aiuta su molti nomi, non su tutti.

## Dopo lo Stop
In Impostazioni › Trascrizione scegli cosa succede a fine registrazione: **trascrivi subito**, **chiedi**, oppure **trascrivi e cancella l'audio** (l'audio viene eliminato solo dopo aver verificato la trascrizione). Puoi anche trascrivere solo quando il Mac è collegato alla corrente.

## Correggere
Puoi ritrascrivere con l'altro motore, rinominare gli speaker, e per documenti ed email correggere il testo a mano (il testo automatico resta ripristinabile). Una trascrizione di Teams (.vtt o .docx) si può allegare a una registrazione.
