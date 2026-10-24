# ADR-0021 — Le note vocali sono note normali; l'audio non si conserva

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: v1.4 sez. 3.22 (FR-210…219), 7.7; addendum C.2, H.21

## Contesto
Dettare una nota è più rapido che scriverla, ma conservare l'audio aggiungerebbe dati sensibili senza valore una volta trascritto.

## Decisione
Una nota vocale è una nota con `input = 'voice'`. L'audio (solo microfono) è un mezzo di inserimento: viene trascritto subito con lo stesso `TranscriptionEngine` delle call (preferendo il motore più rapido) ed eliminato appena la nota è salvata e verificata. Se la trascrizione fallisce, l'audio temporaneo resta finché l'utente riprova o lo scarta. Le note vocali non creano asset e non sono disponibili durante una registrazione di call.

## Conseguenze
- Job di trascrizione ad alta priorità, davanti ai job delle call.
- Audio temporanei in `tmp/voice-notes/`, ripuliti all'avvio.
