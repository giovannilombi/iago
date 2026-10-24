# IAGO — Progetti condivisi tramite una cartella cloud

Bozza di progetto per la fase 4, da discutere. Ottobre 2026.

## In una frase
Un progetto condiviso vive in una **cartella cloud che il gruppo ha già**: OneDrive o SharePoint aziendale, ma anche Google Drive, Dropbox o iCloud Drive. Chiunque abbia accesso alla cartella lo usa in IAGO come se fosse suo.

IAGO non ha un server e non fa connessioni di rete: le fa l'app della cartella cloud.

## Cosa vede l'utente
- Nel menu di un progetto: **Condividi in uno spazio…**. Si sceglie la cartella cloud, per esempio `OneDrive - Azienda/IAGO/Marketing`.
- Accanto al progetto compare l'**icona della cartella cloud**, come oggi compare il logo di Claude per i progetti consultabili da Claude.
- **Da quel momento il progetto non è più "mio".** È dello spazio: chiunque abbia accesso alla cartella lo vede, ci registra, trascrive, aggiunge note e punti chiave, genera sintesi. Ogni contenuto porta il nome di chi l'ha creato.
- **Chi apre la cartella fuori da IAGO** (dal Finder, dal sito di OneDrive, da Teams) trova i materiali **leggibili**: sintesi, trascrizioni, note e punti chiave in Markdown, e gli audio.
- **I progetti non condivisi restano sul Mac, come oggi.**

## Come è fatta la cartella
```
Marketing/                          lo "spazio"
  Portale clienti/                  leggibile da persone
    2026-10-21 Kickoff con Acme.md  sintesi, punti chiave e trascrizione
    2026-10-21 Kickoff con Acme.m4a
    Note/…  Punti chiave.md
  .iago/                            riservata a IAGO
    spazio.json                     nome, regole, proprietario
    membri.json                     chi partecipa e chi è admin (firmato)
    dispositivi/<id>/modifiche/…    il registro di ogni Mac, solo aggiunte
    dispositivi/<id>/istantanee/…   lo stato compatto, ogni tanto
    asset/<impronta>                trascrizioni e documenti originali
```

- **Ogni Mac scrive solo nella propria sottocartella `dispositivi/<id>`.** Due persone non scrivono mai lo stesso file nello stesso momento, quindi la cartella cloud non crea copie in conflitto.
- **Niente database condiviso.** Un archivio SQLite in una cartella sincronizzata si rovina. Ogni Mac tiene il suo archivio e legge i registri degli altri.
- **Conflitti:** se due persone cambiano lo stesso campo, vince l'ultima modifica, con un orologio logico che non dipende dall'ora dei Mac. Sui testi (note, sintesi modificate a mano) si tengono entrambe le versioni e IAGO lo segnala.
- **Cancellazioni:** sono "lapidi" che ogni Mac applica, non file che spariscono.
- **I file leggibili** (Markdown e audio) li rigenera IAGO dal registro: sono una vista, non la fonte. Se qualcuno li modifica a mano in OneDrive, IAGO non li usa come fonte; al massimo segnala la differenza.

## Accesso e riservatezza
- **Decide chi ha accesso alla cartella cloud.** Condividere la cartella con un collega significa dargli accesso al progetto in IAGO. Toglierglielo significa toglierglielo.
- In un'area aziendale protetta la cifratura non serve: i materiali sono volutamente leggibili.
- Un'opzione di cifratura per spazio (degli audio, o di tutto) resta possibile per chi usa cartelle meno protette.

## La regia (admin) senza dipendere da un'azienda o da OneDrive
IAGO sarà distribuito anche fuori dall'azienda, quindi la regia non può contare su un amministratore di OneDrive o su un elenco aziendale. Proposta: la regia è un ruolo dello **spazio**, non dell'azienda.

- **Chi crea uno spazio ne è il proprietario.** Può nominare altri admin e passare la proprietà.
- **Ogni utente ha una propria chiave di firma**, creata da IAGO e tenuta nel Portachiavi.
  - `membri.json` (chi è admin) è firmato dal proprietario.
  - Le azioni da regia sono firmate da un admin: eliminare per tutti, archiviare il progetto, escludere un membro dallo spazio, cambiare le regole (audio sì/no, cifratura).
  - Gli altri Mac applicano solo le azioni firmate da un admin valido. Un file `membri.json` ritoccato a mano, o una "cancellazione" non firmata, vengono rifiutati.
- **Funziona con qualunque cartella cloud**, perché la fiducia sta nelle firme dentro la cartella e non nel servizio che la ospita.
- **Limite onesto:** chi ha accesso in scrittura alla cartella può comunque cancellare dei file con il Finder o dal sito di OneDrive. IAGO non lo può impedire.
  - Ogni Mac tiene la propria copia completa, quindi niente si perde e IAGO può ripubblicare.
  - IAGO si accorge dei file spariti o alterati e lo segnala.
  - OneDrive ha cronologia delle versioni e cestino.

## Cosa resta personale
- I progetti non condivisi.
- Le impostazioni e i collegamenti con Claude.
- Le conversazioni di "Chiedi a IAGO", a meno di salvarle come nota.
- Le registrazioni fatte in un progetto condiviso diventano dello spazio quando sono salvate. Prima resta la possibilità di scartarle.

## Spazio occupato
- Testi: pochi MB per progetto.
- Audio: circa 30 MB per ora di call. Per spazio si sceglie "anche gli audio" oppure "solo testi"; con OneDrive gli audio si possono tenere "solo online" e scaricare su richiesta.

## In più fasi
1. **Spazi e progetti condivisi, solo testi:** registro, conflitti, icona, file leggibili.
2. **Audio** nello spazio.
3. **Regia:** proprietario, admin, azioni firmate.
4. **Prove con altre cartelle cloud** (Google Drive, Dropbox, iCloud) e cifratura facoltativa.

## Domande per la discussione
1. Uno spazio per reparto, uno per cliente, o liberi?
2. Gli audio nello spazio di default, o solo i testi?
3. La regia serve dalla prima versione, o basta il proprietario?
4. Quanto è accettabile che la cartella cloud impieghi qualche minuto a propagare una modifica?
