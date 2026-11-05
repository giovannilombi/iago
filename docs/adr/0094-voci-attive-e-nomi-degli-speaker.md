# ADR-0094 — Riconoscimento delle voci acceso, nomi degli speaker più semplici, il tuo nome

- Stato: accettato
- Data: 2026-11-05
- Modifica: ADR-0073 (riconoscere le voci) e la sua modifica della 1.2.4-beta
- Riferimenti: ADR-0049 (proposte), ADR-0058 (dati), FR-41 (rinominare gli speaker); richiesta dell'utente del 2026-11-05

## Contesto
- Il riconoscimento delle voci era spento di default (ADR-0073). Chi non lo accendeva dava i nomi agli speaker, ma IAGO non salvava nessuna impronta: *Voci conosciute* restava vuota e le call successive non proponevano nomi.
- Il nome di uno speaker si applicava solo con Invio o con il pulsante ⏎ (modifica della 1.2.4-beta). Il campo non confermato era rosso e sembrava un errore. Uscendo dal campo con un clic il nome restava in sospeso, e i nomi già noti non venivano suggeriti mentre si scriveva.
- Il nome dell'utente nelle trascrizioni (*Il tuo nome*) si sceglie al primo avvio. L'impostazione era solo in Generale, l'utente non la trovava, e cambiarla non toccava le call già trascritte.

## Decisione
- **Riconoscimento delle voci acceso di default.** Impostazioni › Voci lo spegne: in quel caso il valore salvato è `0`, e l'assenza del valore vale «acceso». Restano invariate le altre regole di ADR-0073: impronte cifrate con la chiave dell'elemento, mai a Claude, negli export o nella condivisione; proposte da confermare; eliminazione di una voce o di tutte. Anche CLAUDE.md, dove dice «solo con Impostazioni › Voci attivo», resta vero: è attivo finché l'utente non lo spegne.
- **Nome di uno speaker:**
  - mentre si scrive, IAGO suggerisce i nomi che conosce: persone, speaker già nominati e *Presenti*. Prima quelli che iniziano con il testo scritto, poi quelli che lo contengono, senza i nomi già usati nella call;
  - il nome si salva con Invio, con il pulsante ✓ **o uscendo dal campo**. Prima di salvarlo IAGO fa le stesse domande di prima: nomi simili, stesso nome di un altro speaker;
  - il campo non salvato ha il bordo del colore d'accento, non rosso, con la riga *Invio o ✓ per salvare, Esc per annullare*.
- **Call trascritte senza impronte:** se il riconoscimento è acceso ma la call non ha impronte, perché è stata trascritta da spento, sotto i nomi una riga dice di usare *Ritrascrivi* per far imparare le voci.
- **Il tuo nome:** è anche in cima a Impostazioni › Voci, oltre che in Generale. Si applica con Invio, *Salva* o uscendo dal campo. Le call in cui la voce dell'utente ha ancora il nome di prima prendono il nuovo nome (`Archive.renameMe`). Se in una call l'utente ha dato alla propria voce un altro nome, quello resta.

- **«Tu»:** accanto alla voce dell'utente, nella trascrizione e nei nomi degli speaker, compare il segno *Tu*. Vale per la voce del microfono in una call registrata con IAGO e, in un file importato, per lo speaker che ha il nome dell'utente. Passandoci sopra con il mouse si legge quale dei due casi è.

## Conseguenze
- Le impronte si raccolgono dalle call trascritte da ora in poi; per quelle precedenti serve *Ritrascrivi*.
- Un nome scritto e lasciato con un clic non si perde più e non resta in sospeso.
- Dato biometrico acceso di default: la nota in Impostazioni › Voci spiega cosa si salva e dove, e lo si spegne con un clic.
