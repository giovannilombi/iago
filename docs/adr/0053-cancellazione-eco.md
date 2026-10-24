# ADR-0053 — Cancellazione dell'eco di macOS sul microfono

- Stato: ritirato (2026-10-21)
- Data: 2026-10-20
- Riferimenti spec: sez. 6 (cattura); ADR-0002 (due tracce), ADR-0004 (microfono), ADR-0031; richiesta utente 2026-10-20

## Contesto
Senza cuffie il microfono sente anche le casse. Le voci degli altri finiscono così due volte nella registrazione: pulite sulla traccia di sistema, e in ritardo e "metalliche" sulla traccia del microfono. L'ADR-0002 lo prevedeva già ("servono cancellazione d'eco e filtro in trascrizione"), ma la decisione era rimasta aperta.

macOS ha una cancellazione dell'eco nel sistema (*voice processing*, unità `VoiceProcessingIO`), la stessa che usano FaceTime e molte app di call.

## Decisione
- **Impostazione** in Impostazioni › Audio › Microfono: "Cancellazione dell'eco di macOS sul microfono", **attiva di default** (scelta dell'utente dopo la prova). Vale dalla registrazione successiva.
- **Come funziona:**
  - con l'impostazione attiva, la traccia del microfono passa da `VoiceProcessingIO` (`VoiceProcessingMic.swift`) sullo stesso microfono scelto da IAGO (ADR-0004);
  - ogni buffer ha l'ora del suo ingresso, come oggi, così le tracce restano allineate;
  - IAGO non riproduce niente;
  - le altre app vengono abbassate il meno possibile (*ducking* al livello minimo). macOS non permette di toglierlo del tutto: Teams si sente circa 8 dB più piano mentre IAGO registra;
  - i dispositivi nascosti che macOS crea per la cancellazione (`VPAUAggregateAudioDevice…`) non compaiono tra i microfoni.
- **Se la cancellazione non parte** su quel microfono, IAGO registra il microfono normale e lo segna nella timeline della sessione. La registrazione non si perde mai.
- **La traccia di sistema non cambia.**

## Conseguenze
- Senza cuffie la traccia del microfono contiene molta meno voce degli altri: la trascrizione non la duplica e la diarizzazione sbaglia meno.
- La propria voce può risultare un po' più "trattata", come in una call di FaceTime. Con le cuffie la cancellazione non serve, ma non fa danni.
- La cancellazione dell'eco aggiunge alcuni millisecondi di elaborazione. Va verificato che la deriva tra le tracce resti sotto i 50 ms (prova di accettazione su 2 ore).

## Prova del 2026-10-20 (Mac dell'utente, casse del MacBook, voce di prova di 8 s)
| | voce delle casse nel microfono, rispetto all'originale | traccia di sistema |
|---|---|---|
| microfono normale | −0,9 dB | −15,2 dB |
| cancellazione, ducking minimo | −29 dB, appena sopra il rumore della stanza | −23,2 dB (−8 dB) |
| cancellazione, ducking massimo | sotto il rumore | −65 dB (−50 dB) |

- Il *ducking* minimo resta di 8 dB, e l'utente lo accetta.
- La traccia del microfono con cancellazione sembra arrivare circa 35-40 ms più tardi rispetto al microfono normale. È una sola misura, su un residuo debole: va confermata nella prova di accettazione sulla deriva. Se confermata, si compensa con uno spostamento fisso.

## Ritiro (2026-10-21)
- **Problema trovato dall'utente:** con la cancellazione attiva, durante le registrazioni di IAGO **Teams restava senza microfono**. Due unità di elaborazione voce lavoravano sullo stesso microfono, quella di Teams e quella di IAGO: macOS crea un dispositivo intermedio (`VPAUAggregateAudioDevice`) e l'app di call perde l'ingresso.
- **Perché la prova non l'aveva visto:** era stata fatta con un audio riprodotto da `afplay`, senza nessuna app di call aperta.
- **Decisione:** la funzione è **tolta**, codice e impostazione. Un'opzione che toglie il microfono all'app di call non ha senso. IAGO torna a leggere il microfono così com'è (IOProc HAL) e continua a escludere dai microfoni i dispositivi `VPAUAggregate` delle app di call.
- **Per l'eco senza cuffie:**
  - oggi: le cuffie, più il filtro dell'eco residua in trascrizione, che c'era già (ADR-0002);
  - eventuale strada futura, da proporre in un nuovo ADR: pulire la traccia del microfono **dopo** la registrazione, usando la traccia di sistema come riferimento, senza toccare il microfono durante la call.
