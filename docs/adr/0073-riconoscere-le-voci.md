# ADR-0073 — Riconoscere le stesse voci in call diverse

- Stato: accettato
- Data: 2026-10-27
- Riferimenti: ADR-0006 (FluidAudio, diarizzazione), ADR-0028 (chiavi per elemento), ADR-0049 (proposte), ADR-0058 (dati), ADR-0070 (chi ha prodotto un risultato); richiesta dell'utente del 2026-10-27

## Contesto
- Ogni call ha voci "Speaker 1", "Speaker 2"… che l'utente rinomina a mano o con una proposta del motore. Le stesse persone tornano call dopo call.
- La diarizzazione di FluidAudio calcola già per ogni voce un'impronta: 256 numeri, un *embedding* WeSpeaker. IAGO la usava solo dentro la call e poi la buttava.
- L'impronta della voce è un **dato biometrico** (GDPR art. 9): va trattata con più cura del resto.

## Decisione
### Cosa fa
- **Impostazioni › Voci**, *Riconosci le voci tra una call e l'altra*: **spento di default**.
- Da acceso, a ogni trascrizione IAGO conserva l'impronta degli speaker dell'altra parte, o di tutto il file importato, che parlano almeno 10 secondi. La tua traccia ("Io") non ha impronta; le voci della stanza (ADR-0031) per ora nemmeno.
- **Dare un nome a uno speaker insegna la voce**: l'impronta si lega a quella persona. Vale per il nome scritto a mano e per una proposta confermata. Se poi rinomini in un altro nome, l'impronta passa a quello; se torni a "Speaker 2", si slega.
- **Nelle call successive**, uno speaker ancora senza nome che somiglia a una voce conosciuta riceve una proposta: «Speaker 2 diventa Marco», con la riga «Riconosciuta dalla voce (somiglianza 82%)». **Non assegna mai da solo**: si conferma o si scarta come le altre proposte (ADR-0049). Confermando, le altre proposte di nome per lo stesso speaker si scartano.
- **Soglia:** somiglianza del coseno almeno 0,60 e almeno 0,05 sopra la seconda voce più vicina; una voce va al massimo a uno speaker per call, e non si propone una persona già nominata nella stessa call. Valori da tarare con call vere (`Archive.voiceThreshold`, `voiceMargin`).
- Una call già trascritta prima dell'attivazione impara le voci con **Ritrascrivi**: gli speaker che hanno già un nome si legano subito alla loro voce.

### Dati (migrazione `v20-voices`)
- `item_voice`: una riga per speaker di una call, con l'impronta **cifrata con la chiave dell'elemento** (AES-GCM, legata a elemento e speaker), i secondi di parlato e la voce a cui è legata.
- `voice`: solo id e nome (unico, senza distinzione di maiuscole). **L'impronta di una persona non si salva**: si calcola al momento come media delle impronte delle sue call, pesata sui secondi di parlato.
- Così:
  - eliminare una call per sempre (crypto-shredding) toglie la sua parte da ogni impronta;
  - una voce senza più call sparisce da sola;
  - **Elimina** su una voce cancella la voce e le impronte delle call da cui veniva (i nomi nelle trascrizioni restano);
  - **Elimina tutte le voci** (in tre passi: avviso, scrivi DELETE, ultima conferma) cancella anche le impronte degli speaker senza nome.
- Spegnere l'interruttore ferma apprendimento e riconoscimento; le voci salvate restano finché l'utente non le elimina, e il pannello lo dice.
- Le proposte hanno `origin = voice` (ADR-0070) e la somiglianza in percentuale.

### Cosa non fa
- Le impronte non vanno **mai** a Claude (nessuno strumento MCP le legge), negli export, in Obsidian o nella futura condivisione (nessuna riga nel change log). Restano solo nel backup cifrato, perché fanno parte dell'archivio.
- Nessun modello in più: l'impronta esce dalla diarizzazione che già si fa.

## Conseguenze
- Spazio trascurabile: circa 1 KB per speaker per call. Tempo trascurabile: il confronto con decine di voci richiede meno di un millisecondo.
- Con audio compresso, più persone su un microfono di sala o voci simili il riconoscimento può sbagliare; per questo propone soltanto.
- La qualità dipende dalla separazione delle voci: se la diarizzazione unisce due persone, anche l'impronta le mescola.
