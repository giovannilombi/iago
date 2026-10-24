# ADR-0051 — Riconoscere le riunioni Teams, proporre la registrazione e seguire il mute

- Stato: accettato
- Data: 2026-10-19
- Riferimenti spec: sez. 6 (cattura), 4.2 (rete); ADR-0004 (microfono "che sentono gli altri"); richieste utente 2026-10-16 e 2026-10-19

## Contesto
Gli utenti si dimenticano di registrare le call. L'utente vuole che IAGO:
- si accorga di una riunione Teams e proponga di registrarla, con il **titolo della riunione** come titolo provvisorio;
- quando l'utente è in **mute** su Teams, non registri il suo microfono. Teams infatti tiene il microfono aperto anche in mute, come visto nella prova del 12 ottobre.

Non si può coinvolgere l'IT. Cosa è emerso dalle verifiche sul Mac dell'utente:
- leggere le notifiche di altre app non è possibile: macOS non lo consente;
- le cartelle di dati di Teams e Outlook sono protette da macOS ("Operation not permitted"). La cache di Outlook richiederebbe l'accesso completo al disco ed è fragile, quindi si scarta;
- Teams ha un'**API locale per app di terze parti**: un WebSocket su `ws://127.0.0.1:8124`, attivabile dall'utente in Teams › Impostazioni › Privacy. Comunica in-riunione e mute. È documentata solo da progetti della comunità (svrooij/teams-monitor, AntoineGS/teams-status-rs, ferenyl/Teams.ThirdPartyAppApi), non da Microsoft, e l'IT di alcune aziende può disattivarla.

## Decisione
### 1. Più fonti, insieme
| Fonte | Cosa dà | Permesso |
|---|---|---|
| **API locale di Teams** | in riunione, mute | attivarla in Teams, poi un "Consenti" in Teams la prima volta (abbinamento) |
| **App di call che usa il microfono** (Core Audio, già usato per scegliere il microfono, ADR-0004) | inizio e fine di una call Teams, Zoom, Webex, FaceTime, Slack | nessuno in più |
| **Calendario del Mac** (EventKit) | titolo e orario della riunione, se il calendario di lavoro è sincronizzato lì | accesso al Calendario, chiesto solo se l'utente lo attiva |

- **Una call è in corso** se l'API di Teams dice "in riunione" oppure se un'app di call usa il microfono da almeno 5 secondi. Il ritardo evita i falsi allarmi delle prove audio.
- **Il titolo provvisorio** è quello dell'evento del Calendario in corso: se ce n'è più d'uno, si preferisce quello con un link Teams. In mancanza, "Call Teams del 19 ott, 14:30", o con il nome dell'app.
- **All'orario d'inizio di un evento** del Calendario con un link Teams, Zoom o Meet, una notifica chiede "Sta per iniziare «…»: avvio la registrazione?", anche prima di entrare.

### 2. Proposta o registrazione automatica
- Quando inizia una call e IAGO non sta registrando, una notifica chiede **"Sei in una call Teams: avvio la registrazione?"**, con **Registra** e **Non ora**.
  - Senza i permessi di notifica, la proposta compare nel menu della barra.
  - "Non ora" vale per quella call.
- **Impostazione "Quando inizia una call"** (Impostazioni › Audio): *Chiedi* (predefinito), *Registra automaticamente*, *Non fare nulla*. Con "Registra automaticamente" una notifica avvisa che la registrazione è partita, con **Ferma**.
- **A fine call:** se IAGO ha avviato la registrazione da una call rilevata e la call finisce, cioè non più in riunione e microfono libero da 30 secondi, una notifica propone **"La call è finita: fermo la registrazione?"**. Non ferma mai da sola.
- Il titolo provvisorio diventa il titolo dell'elemento (`SessionManifest.suggestedTitle`), modificabile come sempre.

### 3. Mute
- Con l'API di Teams collegata, mentre l'utente è in mute **la traccia del microfono riceve silenzio** e non viene fermata, così le tracce restano allineate. La timeline di sessione segna `micMuted` e `micUnmuted`.
- Senza l'API il mute non si conosce e il microfono resta registrato come oggi. Le Impostazioni lo dicono.

### 4. Rete
- La connessione a `127.0.0.1:8124` è **solo locale**: non esce dal Mac ed è l'unica eccezione nuova. Il codice che la apre è uno solo (`TeamsLocalAPI.swift`), consentito da `check-network-apis.sh`. `CLAUDE.md` › Rete e privacy, punto 2, diventa "localhost verso l'API locale di Teams".
- Il token di abbinamento sta nel Portachiavi.
- Nel registro accessi finiscono solo il collegamento e l'abbinamento, non i singoli stati.

## Conseguenze
- Senza l'IT, e con la sola attivazione dell'API in Teams, IAGO propone di registrare e segue il mute. Senza l'API, il microfono in uso e il Calendario coprono l'inizio delle call e il titolo, ma non il mute.
- Se Microsoft cambia o toglie l'API, resta il resto. Il codice dell'API è isolato e gli errori di collegamento sono solo un avviso nelle Impostazioni.
- La cache di Outlook non si usa.

## Modifica del 2026-10-20
- Sul Mac dell'utente l'API locale di Teams non è disponibile: l'opzione non compare in Teams, quasi certamente bloccata dall'IT. Per il **mute** si aggiunge una seconda fonte, l'**Accessibilità di macOS** (`TeamsAccessibility.swift`):
  - IAGO cerca nella finestra di Teams il pulsante del microfono e ne legge il testo ("Riattiva microfono" vuol dire in mute);
  - si attiva e si disattiva in Impostazioni › Audio › Riunioni, con il permesso Accessibilità;
  - i **testi del pulsante sono modificabili dall'utente** (avanzato), così un cambio di Teams non richiede una nuova versione;
  - IAGO legge solo il testo del pulsante, nient'altro della finestra.
- L'API locale resta, per i Mac dove è attiva. Se ci sono entrambe, vale l'API.
- **La proposta "La call è finita: fermo?"** compare per qualsiasi registrazione in corso quando la call rilevata finisce, non solo per quelle avviate dalla proposta.
- **Le proposte** sono pannelli di IAGO e non notifiche di sistema:
  - Registra e Ignora sempre visibili;
  - restano al massimo 5 minuti, oppure 30 secondi se l'utente lo sceglie;
  - con riunioni sovrapposte ce n'è uno per riunione;
  - in Impostazioni c'è "Mostra un esempio".

## Modifica del 2026-10-20 (2): quale riunione è
L'utente ha aperto una seconda call mentre nel Calendario era ancora in corso "TEAM LEAD", e IAGO ha proposto il titolo sbagliato: sceglieva la riunione iniziata per prima. Ora decide `MeetingMatcher`:
- **certo**, e quindi nessuna domanda, quando:
  - il titolo di una finestra di Teams contiene il nome della riunione: con l'Accessibilità attiva, IAGO legge anche i titoli delle finestre di Teams, solo per confrontarli con il Calendario;
  - oppure una sola riunione è iniziata intorno al momento della call (da 10 minuti prima a 15 minuti dopo l'inizio). Le riunioni con un link di call hanno la precedenza.
- **non certo**: più riunioni iniziate insieme, oppure solo riunioni iniziate da tempo, perché la call potrebbe essere un'altra, non in calendario. In questi casi il pannello chiede quale riunione è, con un pulsante per ciascuna e "Call Teams del …" come ultima scelta:
  - prima di registrare: "Avvio la registrazione? Scegli la riunione:", e ogni pulsante avvia la registrazione con quel titolo;
  - se si sta già registrando: "Quale riunione stai registrando?". Finché l'utente non sceglie resta la migliore ipotesi.
- Il titolo si ricalcola quando parte la registrazione, perché la call potrebbe essere cambiata. Se l'utente ha scelto da un pannello, vale la sua scelta.
