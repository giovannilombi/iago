# IAGO — Lavoro aperto: due modalità, Traccia e Gestisci

Progetto da rileggere prima di scrivere codice. 28 ottobre 2026. Decisione collegata: [ADR-0074](../adr/0074-lavoro-aperto-traccia-gestisci.md) (proposto).

## In una frase
IAGO resta la memoria del lavoro, e tiene anche traccia di **ciò che è aperto**: attività, punti da chiarire, rischi, richieste. **Tutti i tipi ci sono sempre.** Cambia solo quanta gestione si vede:
- **Traccia** (predefinita): semplice come oggi;
- **Gestisci**: aggiunge stati fini, campi, kanban e riepilogo completo.

Si passa dall'una all'altra senza perdere nulla.

## Perché
- Oggi i punti chiave sono decisione, attività e tappa. Un'attività ha solo testo, persone e lo stato aperta/fatta: non c'è un responsabile esplicito, né una scadenza, né "in attesa di".
- Il tipo "punto da chiarire" esiste nel modello (`openQuestion`, ADR-0014) ma non si vede.
- IAGO lo usano sia gli operativi sia i PM. Ai PM serve sapere **cosa è aperto, di chi è, per quando, cosa blocca**, e la timeline non lo dice.
- Non si vuole un Jira peggiore: niente sprint, niente calcolo delle stime, niente flussi da configurare.

## I tipi
Due nature. La **memoria** registra ciò che è avvenuto e non si "fa". Il **lavoro** è aperto finché qualcuno non lo chiude.

| Natura | Tipo | Segno | `kind` | Cos'è |
|---|---|---|---|---|
| Memoria | **Decisione** | ◆ sigillo verde | `decision` | qualcosa di deciso; vale finché un'altra non la sostituisce |
| Memoria | **Tappa** | ⚑ bandierina blu | `milestone` | un fatto importante: firma, consegna, kickoff |
| Lavoro | **Attività** | ○ cerchio arancione | `action` | cosa fare, anche con una checklist (to-do multiplo) |
| Lavoro | **Punto da chiarire** | ? punto viola | `open_question` | una domanda che aspetta risposta |
| Lavoro | **Rischio** | ⚠ triangolo rosso | `risk` | cosa può andare storto, con gravità; se accade diventa un problema |
| Lavoro | **Richiesta** | ✉ busta azzurra | `request` | cosa chiede il cliente; si accoglie o si rifiuta |

Le note restano note: si possono **promuovere** a qualsiasi tipo, come oggi.

## Come si collegano: tre legami
1. **Supera / chiude** (il legame di oggi, ADR-0052). Una voce più recente chiude quella più vecchia. La riga lo legge con il verbo giusto per i due tipi:

   | Chi | → chi | Si legge | Effetto sulla voce più vecchia |
   |---|---|---|---|
   | Decisione | → Decisione | «sostituisce» | Superata |
   | Decisione | → Punto da chiarire | «risponde a» | Chiarito (la decisione è la risposta) |
   | Decisione o Attività | → Richiesta | «accoglie» | Accolta |
   | Tappa o Decisione | → Attività | «completa» | Fatta |
   | Tappa | → Tappa | «sostituisce» | Superata |
   | qualsiasi | → qualsiasi altro caso | «supera» | chiusa |

   Regole di ADR-0052 invariate: legami multipli, niente cerchi, togliendo il legame la voce torna aperta.
2. **Nata da.** Una voce nasce da un'altra e la ricorda:
   - attività nate da una richiesta accolta;
   - un'attività di mitigazione nata da un rischio;
   - un punto da chiarire nato da una decisione.

   Non chiude nulla: il rischio resta aperto finché non lo chiudi tu.
3. **Dipende da.** «Bloccata finché X non è chiusa». Quando tutte le voci da cui dipende sono chiuse, torna come prima.

Le **checklist** non sono un legame: sono le sotto-voci di un'attività (vedi sotto).

## Stati
Le voci di **memoria** hanno gli stati di oggi: attiva, superata, annullata.

Le voci di **lavoro** hanno sei stati. Nella modalità Traccia se ne vedono quattro:

| Stato (Gestisci) | Visto in Traccia | `status` |
|---|---|---|
| Da fare | Aperta | `active` (come oggi: nessuna migrazione dei dati) |
| In corso | Aperta | `in_progress` |
| In attesa (di chi, entro quando) | In attesa | `waiting` |
| Bloccata | Aperta, con il segno «bloccata» | `blocked`: automatico se una dipendenza è aperta, oppure a mano |
| Fatta | Fatta | `done` |
| Annullata | Annullata | `cancelled` |
| *(chiusa da un'altra voce)* | Chiarito / Accolta / Fatta, secondo il verbo | `superseded`, come oggi |

**Chiusure con esito**, nel campo `outcome`:
- **Punto da chiarire:** si chiude con la **risposta**. La risposta si scrive, oppure si prende da una frase di una call o di una mail con la sua fonte. Il pulsante «Diventa decisione» crea una decisione che *risponde a* il punto.
- **Richiesta:** si chiude **accolta** (crea una o più attività *nate da* lei, oppure una decisione che *accoglie*), **rifiutata** (con il motivo) o **trasformata** in un altro tipo.
- **Rischio:** ha la **gravità** alta, media o bassa. Si segna **«Diventato problema»**, con la data, e la storia resta nella stessa voce. Si chiude come **risolto** o **non più rilevante**.

## Campi
Tutti facoltativi.

| Campo | Traccia | Gestisci | Note |
|---|---|---|---|
| Titolo, tipo, descrizione, data, fonte, persone, tag, stream | ✓ | ✓ | come oggi |
| **Responsabile** | ✓ | ✓ | persona già nota o nuova; «Io» sempre in cima |
| **Scadenza** | ✓ | ✓ | |
| **In attesa di** (persona, entro quando) | ✓ | ✓ | |
| **Checklist** | ✓ | ✓ | sotto-voci da spuntare |
| Priorità (alta, media, bassa) | — | ✓ | |
| Dipende da | segno «bloccata» | ✓ | |
| Stima, data d'inizio | — | ✓ | solo da riportare, nessun calcolo |
| Ricorrenza (giorno, settimana, mese, anno) | — | ✓ | chiusa una, si crea la successiva |
| Colonna libera della kanban | — | ✓ | |

**Persone.** Si sceglie tra quelle che IAGO conosce già (speaker, contatti email, persone dei punti chiave, voci) o si scrive un nome nuovo. Su un nome nuovo, IAGO controlla le somiglianze: «Intendi Marco Rossi?». Le persone sono le `entity` di tipo persona già esistenti.

In **Traccia** un campo di Gestisci già compilato non si perde: resta salvato e una piccola icona dice «ha dettagli in Gestisci».

## Le due modalità
| | **Traccia** (predefinita) | **Gestisci** |
|---|---|---|
| Tipi | tutti | tutti |
| Stati di lavoro visibili | Aperta · In attesa · Fatta · Annullata | tutti e sei |
| Scheda di una voce | titolo, tipo, responsabile, scadenza, in attesa di, checklist, descrizione | anche «Altri dettagli»: priorità, dipendenze, stima, inizio, ricorrenza |
| Viste | Timeline, Punti chiave, **Da fare** (inbox), **Riepilogo** breve, Grafo | in più **Kanban** (progetto e globale), **Riepilogo** completo, filtri per persona e priorità |
| Notifica del mattino | disponibile, spenta | disponibile, accesa |
| Proposte del motore e di Claude | tutti i tipi | tutti i tipi |

- **Dove si sceglie:** Impostazioni › Generale e nel tour di benvenuto («Come usi IAGO? *Tengo traccia* / *Gestisco i progetti*»).
- **Per persona, con eccezioni per progetto:** in Gestisci un progetto può restare in Traccia. Nella sua pagina si vede Traccia, ma le voci assegnate a te restano nella tua inbox.
- **Kanban:** in Gestisci è accesa di default e ha un suo interruttore. Spenta, le colonne libere e le posizioni restano salvate.

## Le viste

### Timeline (entrambe le modalità)
Resta la **memoria del progetto**: ordinata per data, ogni voce alla sua data (della decisione, della tappa o del momento in cui la voce di lavoro è emersa). **Chiudere una voce non crea una riga nuova**: cambia il suo aspetto.

| Stato | Come si vede |
|---|---|
| Aperta | segno e colore del tipo, testo normale; responsabile e scadenza in piccolo |
| In ritardo | la scadenza diventa rossa |
| In attesa | etichetta «attende Anna · entro 5 nov» |
| Bloccata | etichetta «bloccata» |
| Fatta | ✓ verde, testo grigio **non barrato** (è un esito positivo) |
| Chiarito / Accolta / Rifiutata | una riga: «? Quale provider? → *Usiamo Azure AD*», «accolta», «rifiutata: fuori budget» |
| Superata / Annullata | testo **barrato** grigio, come oggi |

Una voce chiusa da un'altra **sta sotto di lei** se è dello stesso giorno, come oggi per le decisioni superate. Altrimenti resta alla sua data con «→ chiusa da …».

Esempio (dal più recente):
```
20 nov  ⚑ Tappa      Firmato ordine SSO                 completa ↓
          └ ✓ Attività  Preventivo SSO · Marco           fatta
 8 nov  ◆ Decisione  Usiamo Azure AD                    risponde a ↓
          └ ? Quale provider SSO?                        chiarito
 3 nov  📞 Call «SAL settimanale»
        ✉ Richiesta  Login SSO per i dipendenti         accolta → 1 attività
        ○ Attività   Preventivo SSO · Marco · entro 10 nov   (nata dalla richiesta)
```

### Da fare (inbox, entrambe le modalità)
Nella barra laterale, sempre presente. Mostra solo il lavoro aperto, di tutti i progetti:
- **le mie voci:** in ritardo, oggi, questa settimana, più avanti, senza data;
- **Aspetto da altri:** le voci in attesa che seguo io, con la data promessa e il ritardo;
- **Proposte da confermare** del motore e di Claude;
- **Checklist fissate** dei progetti.

Le voci chiuse escono dalla vista. **«Mostra chiuse»** le richiama.

Esempio:
```
Da fare                                         [ Mostra chiuse ]
In ritardo
  ○ Inviare il preventivo SSO      Portale · 2 giorni fa
Oggi
  ? Quale provider SSO?            Portale · Io
Questa settimana
  ⚠ Ritardo fornitore (alta)       Logistica · ven
Aspetto da altri
  ○ File definitivi                Acme · Anna · entro ieri
Proposte da confermare (3)
Checklist fissate
  ☐ Consegna finale (4/7)          Portale
```

### Riepilogo di progetto (entrambe le modalità)
Una pagina per progetto (e per cliente e stream):
- **Traccia, versione breve:** voci aperte per tipo, prossime scadenze, decisioni e tappe recenti, checklist fissate.
- **Gestisci, versione completa:**
  - **stato e avanzamento:** aperti e chiusi per tipo, in ritardo, bloccati, prossime tappe;
  - **cosa è cambiato** dall'ultima volta che l'hai aperta;
  - **rischi per gravità, punti da chiarire, attese da altri;**
  - **sintesi scritta di stato,** generata dal motore o da Claude, da copiare in una mail. Le citazioni sono verificate come nelle sintesi (ADR-0054).

### Kanban (solo Gestisci)
- **Una board per progetto, cliente e stream, e una globale** con filtri per progetto, persona e tipo.
- **Colonne fisse:** Da fare, In corso, In attesa, Bloccata, Fatta. Spostare una voce da una colonna fissa all'altra **cambia il suo stato**.
- **Colonne libere** dell'utente, aggiunte dopo quelle fisse (per esempio «Da discutere venerdì», «Idee»). Mettere una voce in una colonna libera **non cambia il suo stato**: serve a raggrupparla. Ogni board ha le sue colonne libere.
- La colonna Fatta mostra solo le voci chiuse di recente (14 giorni); il resto si vede con «Mostra chiuse».

```
Da fare │ In corso         │ In attesa         │ Bloccata │ Fatta ║ Da discutere
        │ ○ Preventivo SSO │ ? Quale provider  │          │       ║ ✉ App mobile
        │   Marco · 10/11  │   attende cliente │          │       ║
```

### Punti chiave e Grafo
Restano come oggi, con i tipi nuovi:
- nel filtro per tipo compaiono i tipi nuovi;
- nel grafo ogni tipo ha la sua forma;
- i legami «nata da» e «dipende da» sono tratteggiati.

## Notifica del mattino
Un solo avviso, all'ora scelta, nei giorni lavorativi: «3 in scadenza oggi, 2 in ritardo, 1 attesa scaduta». Un clic apre Da fare. Si accende e si spegne in Impostazioni; di default è spenta in Traccia e accesa in Gestisci.

## Proposte del motore e di Claude
- **Il motore** propone tutti i tipi in entrambe le modalità (ADR-0049), ciascuno con la frase da cui viene:
  - punti da chiarire;
  - rischi con gravità;
  - richieste del cliente;
  - attività con responsabile, scadenza o «in attesa di», quando la call li dice («Anna ci manda i file entro venerdì»).
- Una proposta può anche **chiudere** una voce aperta, per esempio «questa decisione risponde a *Quale provider?*», come oggi propone i superamenti.
- **Claude, via MCP:**
  - `add_decision`, `update_decision` e `list_decisions` accettano i tipi, gli stati e i campi nuovi;
  - `propose_suggestions` accetta i tipi nuovi (ADR-0071).

  L'anteprima e l'annullamento funzionano come oggi.
- Le proposte dei tipi nuovi vanno provate con il banco di prova su call vere prima di essere attive di default.

## Esportazioni
- **Markdown di progetto e Obsidian:** i tipi e gli stati nuovi, con responsabile, scadenza, esito e checklist (`[Rischio · alta · Aperto]`, `[Punto da chiarire · Chiarito] → risposta`).
- **Sintesi di stato:** copiabile come testo.

## Dati
Una migrazione (`v21-work`) che **aggiunge** e non cambia nulla di ciò che c'è.

**Colonne nuove nella tabella `decision`:**

| Colonna | Tipo | Uso |
|---|---|---|
| `owner_id` | testo, → `entity` | responsabile |
| `due_at` | data | scadenza |
| `waiting_on_id`, `waiting_until` | → `entity`, data | in attesa di |
| `priority` | intero (1 alta, 2 media, 3 bassa) | |
| `starts_at`, `estimate` | data, testo | solo da riportare |
| `severity` | testo (`high`, `medium`, `low`) | rischio |
| `happened_at` | data | rischio diventato problema |
| `outcome` | testo | risposta, motivo del rifiuto, esito |
| `outcome_kind` | testo (`answered`, `accepted`, `rejected`, `converted`, `resolved`, `irrelevant`) | |
| `derived_from_id` | → `decision` | nata da |
| `recurrence` | testo (`daily`, `weekly`, `monthly`, `yearly`) | |
| `closed_at` | data | quando è stata chiusa (per «Mostra chiuse» e per il riepilogo) |

**Tabelle nuove:**
- `decision_dependency (blocked_id, blocker_id)`;
- `checklist (id, project_id, name, pinned, sort)`, per le liste di progetto;
- `checklist_item (id, decision_id | checklist_id, text, done, sort)`;
- `board_column (id, scope, name, sort)` e `board_place (scope, decision_id, column_id)`, per le colonne libere di ogni board;
- `project.work_mode` (nullo = come l'app) e l'impostazione `work.mode` (`track` | `manage`).

`kind` e `status` sono testo: i valori nuovi (`risk`, `request`, `in_progress`, `waiting`, `blocked`) non richiedono di convertire i dati. Le attività di oggi restano `active` (Da fare) o `done`. Tutte le tabelle hanno le colonne di sincronizzazione e il change log (ADR-0008), pronte per la condivisione.

## Provare senza rischi
- **Il codice resta separato.** Si lavora sul branch `feat/lavoro`, una PR per fase verso quel branch, con la CI. `main` resta la versione di oggi, anche per Gianluca. Su `main` si unisce solo dopo l'approvazione.
- **L'archivio vero non viene mai toccato.** La migrazione `v21` cambia il database, e una versione precedente di IAGO non saprebbe leggere gli stati nuovi. Lo script `scripts/try-branch.sh`:
  1. chiede di chiudere IAGO;
  2. copia l'archivio in una cartella di prova (`~/IAGO-prova/`);
  3. compila la build del branch e la apre su quella copia (`-IAGODemoRoot`, ADR-0061).

  La chiave dell'archivio è la stessa nel Portachiavi, quindi la copia si apre con tutti i contenuti.
- **Tornare alla versione di oggi** vuol dire chiudere la build di prova e riaprire IAGO normale: l'archivio è com'era. La copia si butta o si rifà quando si vuole.
- **Attenzione:** mentre si prova, le registrazioni nuove vanno nella copia. Per il lavoro vero si usa IAGO normale.

## Fasi
Una PR per fase verso `feat/lavoro`, ciascuna provabile da sola sulla copia.

1. **Modello e scheda**
   - tipi, stati, campi, legami, checklist, migrazione `v21`;
   - le due modalità e la scelta per progetto;
   - scheda e timeline come descritte sopra;
   - MCP, esportazioni, grafo;
   - script di prova.
2. **Da fare e Riepilogo:** inbox, «Mostra chiuse», riepilogo breve e completo, sintesi di stato, notifica del mattino.
3. **Kanban:** board di progetto e globale, colonne libere, dipendenze nella scheda, ricorrenze.
4. **Proposte:** motore e Claude per i tipi nuovi, con il banco di prova su call vere.

Dopo l'approvazione: unione su `main`, guida, tour e prove per i tester.

## In attesa (obiettivi da riaprire)
- **Calendari:** Calendario del Mac, Google e Microsoft nei due sensi. Per Google e Microsoft serve un ADR con un'eccezione di rete (login, token nel Portachiavi, registro accessi); gli account aziendali possono richiedere l'approvazione dell'IT, Google la verifica dell'app.
- **Pianifica la giornata:** un passaggio guidato al mattino (stile any.do) sulle voci di oggi, in ritardo e in attesa.
- **Inviare attività ad altri** prima della condivisione (fase 4): via mail, messaggio o file da importare.
- **Sprint e calcolo delle stime:** esclusi per scelta.
