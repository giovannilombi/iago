# ADR-0055 — Sezione "Attività"

- Stato: accettato
- Data: 2026-10-21
- Riferimenti spec: sez. 12 (job), 16 (UI); richiesta utente 2026-10-21

## Contesto
I lavori di IAGO mostrano il loro stato in posti diversi:
- registrazione e trascrizione nella barra dei menu;
- trascrizione anche nella scheda dell'elemento;
- download e indicizzazione in Impostazioni;
- proposte nella scheda.

L'utente vuole un unico posto, sotto Importa, con tutto quello che è in corso e la percentuale.

## Decisione
- **Voce "Attività" nella barra laterale**, sotto Importa, con un segno che conta i lavori in corso o in coda. Il segno sparisce quando non c'è niente.
- **La vista ha tre gruppi:**
  - **In corso**, ciascuno con barra, percentuale e, quando si può stimare, il tempo rimasto:
    - registrazione: durata, microfono, cancellazione dell'eco, mute, con "Apri", "Pausa" e "Ferma";
    - trascrizione;
    - punti chiave e proposte, riordino del testo e sintesi (ADR-0054). Per i lavori del motore la percentuale viene dai blocchi completati;
    - indicizzazione per la ricerca per significato;
    - download dei modelli (trascrizione, motore, ricerca);
    - import da cartelle sorvegliate e da Claude, backup, esportazioni.
  - **In coda**: l'ordine dei lavori, con "Annulla" e "Fai prima questo".
  - **Finite di recente** (ultime 24 ore) e **non riuscite**, con "Apri l'elemento" e "Riprova".
- **Dove si legge:** la vista legge gli stessi stati che già usano la barra dei menu e le Impostazioni (coda dei lavori, registratore, motore, download). Non c'è un registro nuovo: le finite di recente vengono dalla tabella `job` e dai lavori della sessione.
- **Contenuti:** solo titoli degli elementi e tipi di lavoro, mai testo delle trascrizioni.

## Conseguenze
- Un posto solo per capire cosa sta facendo IAGO e perché la ventola gira.
- Ogni nuovo tipo di lavoro deve comparire qui. È una regola come quella dei Permessi.
