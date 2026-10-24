# Risoluzione problemi e log

I problemi più frequenti, con la soluzione, sono in [Problemi comuni](/guida/problemi). Qui trovi come capire cosa sta succedendo e come raccogliere informazioni da mandare a chi ti aiuta.

## Prima di tutto
1. **Impostazioni › Permessi:** ogni voce deve essere verde. Un permesso negato si riattiva in **Impostazioni di Sistema › Privacy e sicurezza**, poi si riavvia IAGO.
2. **Attività** (nella barra laterale): mostra cosa sta facendo IAGO, con la percentuale. I lavori pesanti vanno uno alla volta e si fermano durante le registrazioni.
3. **Riavvia IAGO:** menu dell'icona › **Esci**, poi riaprilo da Applicazioni. Una registrazione interrotta viene recuperata all'avvio.

## Problemi frequenti

| Sintomo | Cosa fare |
|---|---|
| "Nessun audio di sistema" nella prova | Attiva IAGO in **Privacy e sicurezza › Registrazione dello schermo e dell'audio di sistema** e riavvialo |
| Le voci degli altri anche sulla mia traccia | Usa le cuffie; in trascrizione IAGO scarta comunque le frasi ripetute |
| Non compare la proposta di registrare | **Impostazioni › Audio › Riunioni**: controlla la riga di stato e prova *Mostra un esempio di proposta* |
| Il titolo della riunione manca o è sbagliato | Collega il calendario di lavoro (vedi [Riunioni e calendario](/guida/riunioni)) |
| Il mute di Teams non viene seguito | Attiva l'**Accessibilità** per IAGO |
| La sintesi non parte | Serve il motore locale, almeno Qwen 3.5 9B, e una categoria con un modello di sintesi |
| Nomi scritti male nella trascrizione | Aggiungili al **glossario** (Impostazioni › Trascrizione) e ritrascrivi |
| macOS dice che IAGO non si può aprire | Vedi ["Apri comunque"](/installazione) |

## I log di IAGO
IAGO scrive i suoi log nel sistema di log di macOS. **Non contengono i contenuti** delle tue call, trascrizioni o documenti: solo eventi tecnici (avvio, permessi, errori, durata dei lavori).

### Con l'app Console
1. Apri **Console** (Applicazioni › Utility).
2. Seleziona il tuo Mac a sinistra e premi **Avvia lo streaming**.
3. Nel campo di ricerca scrivi `subsystem:com.giovannilombi.iago`.
4. Riproduci il problema, poi seleziona le righe e copiale.

### Dal Terminale
Le ultime due ore:

```sh
log show --last 2h --info --predicate 'subsystem == "com.giovannilombi.iago"'
```

In diretta, mentre riproduci il problema:

```sh
log stream --info --predicate 'subsystem == "com.giovannilombi.iago"'
```

Solo un'area, per esempio la trascrizione:

```sh
log show --last 2h --info --predicate 'subsystem == "com.giovannilombi.iago" AND category == "transcription"'
```

| Categoria | Cosa riguarda |
|---|---|
| `app` | avvio, finestre, permessi |
| `calls` | proposte di registrare, riunioni, calendario |
| `teams` | mute di Teams e API locale di Teams |
| `transcription` | coda dei lavori e trascrizione |
| `archive` | archivio, file cifrati, cestino |
| `import` | importazioni e cartelle sorvegliate |
| `engine` | motore locale e modelli |
| `intelligence` | ricerca, proposte, Chiedi |
| `backup` | backup e ripristino |
| `update` | controllo degli aggiornamenti |

### Registro accessi
**Impostazioni › Privacy › Registro accessi** elenca ogni connessione di rete di IAGO (download dei modelli, controllo degli aggiornamenti, API locale di Teams) e ogni lettura o scrittura fatta da Claude, se l'hai collegato.

## Chiedere aiuto
Quando segnali un problema scrivi:
- la versione di IAGO (**Impostazioni › Generale › Aggiornamenti**) e di macOS;
- cosa hai fatto, cosa ti aspettavi e cosa è successo;
- le righe di log del momento del problema.

Non allegare registrazioni, trascrizioni o documenti di lavoro: descrivi il comportamento, non il contenuto.
