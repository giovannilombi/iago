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
- **Microfono assente** (ADR-0093): `TrackWriter.lastBufferPosition` segna l'ultimo buffer arrivato, con segnale o no; `SilenceAlarm.micAbsent` dà vero dopo 2 secondi senza buffer dal microfono (`absentWindow`) o senza dispositivo. Il silenzio non conta: un microfono che ascolta manda comunque buffer. `RecordingController.Snapshot.micAbsent` lo porta all'interfaccia, che lo legge ogni secondo: pallino giallo sull'icona di IAGO, riga nel menu e nella barra di registrazione, e un pannello (`CallPrompts`, come le proposte di registrazione) gestito da `StatusItemController.updateMicPanels`, che non torna dopo una risposta finché il microfono non riprende.
- **Traccia muta** (FR-16): dopo 30 secondi di silenzio su una traccia mentre l'altra ha segnale, una riga nel menu e nella barra di registrazione; per il microfono anche un pannello, una volta per registrazione. Non colora più il pallino.

## Interfaccia di registrazione
- Clic sull'icona: menu; clic destro o ctrl-clic: avvia, pausa e ripresa. Così un clic distratto non mette mai in pausa una call (ADR-0026).
- **Segna momento** mette il segnalibro 5 secondi prima del clic (ADR-0024).
- **Scarta** tiene la registrazione recuperabile per un'ora (ADR-0032).
- **Segna momento con screenshot** (ADR-0072): `ScreenshotService` cattura con ScreenCaptureKit (`SCScreenshotManager`) lo schermo sotto il puntatore, o tutti, escludendo le finestre di IAGO; il testo si legge con l'OCR di Vision (`ContentExtractor.extract(image:)`). PNG e testo vanno nella cartella della sessione con un marcatore `screenshot` in `session.json`; `RecordingArchiver` li cifra come asset `screenshot` dell'elemento, con `at_sec` e `text` (migrazione `v19-screenshots`). Il testo entra nell'indice di ricerca come riga della trascrizione e nelle righe che leggono motore e Claude (`SuggestionEngine.Input.load`).
- **Scorciatoie globali** (`GlobalShortcuts`): `RegisterEventHotKey` di Carbon, senza permessi; ⌃⌥M, ⌃⌥S, ⌃⌥R di default, salvate nell'archivio (`shortcut.<azione>`), modificabili o spente. Ogni combinazione contiene ⌃ o ⌥ (mai solo ⌘) e non può ripetere quella di un'altra azione di IAGO.
- Il minuto di una schermata è quello della richiesta (`HostClock` al tasto), non la fine di cattura e OCR; con più schermi si catturano tutti subito e si leggono dopo, fuori dal thread principale. Un'importazione interrotta da un crash non duplica le schermate, e una schermata eliminata (o l'elemento) non lascia il suo testo nel database.

## Riunioni
Rilevamento solo locale (ADR-0051):
- **App che usano il microfono** (Teams, Zoom, Webex, FaceTime, Slack…), lette dagli oggetti processo di Core Audio.
- **Calendario del Mac** con EventKit, per il titolo e la proposta all'orario d'inizio; con più riunioni sovrapposte `MeetingMatcher` sceglie la candidata migliore e, se è incerto, chiede all'utente.
- **Titoli delle finestre di Teams** via Accessibilità, per riconoscere la riunione giusta.
- **Mute di Teams** via Accessibilità (pulsante del microfono) oppure via **API locale di Teams** su `127.0.0.1:8124`, solo se l'utente la attiva: durante il mute la traccia del microfono riceve un marcatore. Il pulsante del microfono si cerca nelle finestre di Teams fuori dal thread principale (`TeamsAccessibility.search`, fino a 6.000 elementi): ogni 3 secondi se Teams usa il microfono o era in riunione, ogni 20 secondi altrimenti; trovato il pulsante, si rilegge solo la sua etichetta ogni secondo.
- La proposta di registrare compare in un `NSPanel` con le scelte (registra, ignora, riunione giusta).
