# ADR-0031 — Opzione "Più persone nella stanza"

- Stato: accettato (richiesta dell'utente, 2026-10-12)
- Data: 2026-10-12
- Riferimenti spec: sez. 7.2, FR-41; ADR-0002, ADR-0006

## Contesto
La pipeline assegna tutta la traccia mic allo speaker "Io" e diarizza solo la traccia di sistema (spec 7.2, ADR-0006). Nella prova del blocco 3 due persone nella stessa stanza, entrambe sul microfono del Mac, sono finite tutte sotto "Io".

## Decisione
- Opzione per elemento **"Più persone nella stanza"**, scelta nel pannello post-registrazione o nella scheda quando si trascrive o ritrascrive (default spento).
- Con l'opzione attiva la traccia mic viene diarizzata come quella di sistema. La voce con più parlato è "Io" (`me`); le altre diventano `r2`, `r3`… con etichetta "Stanza 2", "Stanza 3"…, rinominabili come gli altri speaker (FR-41).
- Il filtro eco si applica ai segmenti mic già divisi per speaker.
- Per gli elementi importati (una traccia sola) non cambia nulla: sono già diarizzati per intero.

## Conseguenze
- Deroga a spec 7.2 passo 3 e ad ADR-0006 solo quando l'opzione è attiva.
- La voce principale è scelta per durata: se l'utente parla meno degli altri presenti va rinominata a mano.
- Diarizzazione in più sulla traccia mic: pochi secondi per ora di audio.

## Modifica del 2026-10-30 (1.2.8-beta)
Richiesta dell'utente: spesso non si sa prima che ci saranno più persone, e avviare la registrazione deve restare immediato.
- **IAGO decide da solo** (`RoomMode.auto`, il nuovo predefinito): il microfono viene sempre diarizzato. Se la traccia di sistema ha meno di 10 s di parlato è una riunione in presenza e le voci con almeno 20 s di parlato si separano da sole. Con una call restano su «Io», perché l'eco della call confonde, e la scheda propone *Separa le voci*, che ritrascrive con l'opzione attiva.
- Le voci più brevi di 20 s restano con l'utente: di solito sono la sua stessa voce divisa in due, o un rumore.
- **Durante la registrazione:** *Più persone qui nella stanza* nel menu dell'icona; la trascrizione automatica e il pannello dopo lo Stop lo usano.
- **Presenti** (migrazione `v24-attendees`): l'utente può scrivere chi c'era, durante il pannello dopo lo Stop o dopo nella scheda. I nomi sono proposti per gli speaker ancora senza nome e vanno nelle esportazioni; non sono collegati alle voci finché l'utente non dà un nome.
- Le voci della stanza separate hanno la loro impronta (ADR-0073).
- Per chi è collegato da remoto non cambia nulla: la traccia di sistema era già separata per voce, anche con più persone dallo stesso computer.
- Registrare solo il microfono, senza l'audio del Mac, resta per dopo: con l'audio del Mac muto il risultato è lo stesso.
