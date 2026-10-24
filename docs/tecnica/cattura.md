# Cattura e riunioni

## Due tracce
IAGO registra **due tracce separate** (ADR-0002): l'audio del Mac (gli altri) e il microfono (tu). Così sa sempre chi è l'utente ("Io"), trascrive meglio e può scartare l'eco.

| Traccia | Come | ADR |
|---|---|---|
| Sistema | *process tap* di Core Audio (macOS 14.2+) su tutto l'audio in uscita, con un dispositivo aggregato privato | 0003 |
| Microfono | IOProc HAL sul dispositivo d'ingresso, letto così com'è, senza toccare quello dell'app di call | 0004 |

- Ogni buffer porta l'**host time** dell'orologio di sistema: le tracce restano allineate anche con pause e cambi di microfono. Obiettivo: deriva sotto i 50 ms in 2 ore.
- **Microfono automatico:** IAGO usa lo stesso microfono dell'app di call, lo segue se cambia (cuffie collegate o tolte), e con più ingressi preferisce quello predefinito del Mac; attende qualche secondo prima di ripiegare sul predefinito (ADR-0025).
- **Nessun voice processing:** la cancellazione dell'eco di macOS (VPIO) è stata provata e ritirata, perché toglieva il microfono a Teams durante la registrazione (ADR-0053). Anche la pulizia dell'eco dopo la registrazione è stata rifiutata (ADR-0064). L'eco si gestisce in trascrizione.

## Scrittura e recupero
- Scrittura **incrementale** in `tmp/sessions/<id>/`, con *flush* al massimo ogni 2 secondi e un `session.json` con marcatori (pausa, cambio dispositivo, segnalibri).
- A fine registrazione le tracce vengono finalizzate in AAC e cifrate nell'archivio.
- **Recovery all'avvio:** una sessione non finalizzata (crash, spegnimento) viene recuperata; una traccia vuota viene riempita di silenzio per restare allineata.
- **Sonno del Mac:** pausa automatica e scelta al risveglio.
- **Traccia muta:** dopo 30 secondi di silenzio su una traccia IAGO avvisa.

## Interfaccia di registrazione
- Clic sull'icona: menu; clic destro o ctrl-clic: avvia, pausa e ripresa. Così un clic distratto non mette mai in pausa una call (ADR-0026).
- **Segna momento** mette il segnalibro 5 secondi prima del clic (ADR-0024).
- **Scarta** tiene la registrazione recuperabile per un'ora (ADR-0032).

## Riunioni
Rilevamento solo locale (ADR-0051):
- **App che usano il microfono** (Teams, Zoom, Webex, FaceTime, Slack…), lette dagli oggetti processo di Core Audio.
- **Calendario del Mac** con EventKit, per il titolo e la proposta all'orario d'inizio; con più riunioni sovrapposte `MeetingMatcher` sceglie la candidata migliore e, se è incerto, chiede all'utente.
- **Titoli delle finestre di Teams** via Accessibilità, per riconoscere la riunione giusta.
- **Mute di Teams** via Accessibilità (pulsante del microfono) oppure via **API locale di Teams** su `127.0.0.1:8124`, solo se l'utente la attiva: durante il mute la traccia del microfono riceve un marcatore.
- La proposta di registrare compare in un `NSPanel` con le scelte (registra, ignora, riunione giusta).
