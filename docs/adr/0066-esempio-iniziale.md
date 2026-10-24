# ADR-0066 — Esempio iniziale in un archivio nuovo

- Stato: accettato
- Data: 2026-10-24
- Riferimenti: ADR-0038 (cliente › progetto › stream), ADR-0063 (barra laterale), ADR-0065 (niente dati reali)

## Contesto
- L'app distribuita non deve contenere nessun contenuto: tutto quello che l'utente crea resta suo, sul suo Mac.
- Una barra laterale vuota però non mostra come si organizza il lavoro (cliente, progetti, stream, "In evidenza").

## Decisione
- In un archivio **nuovo e vuoto** (nessun cliente, progetto o elemento; configurazione iniziale non ancora fatta), al primo avvio IAGO crea:
  - il cliente **Cliente Test**;
  - i progetti **Pj. Test 1** e **Pj. Test 2**;
  - in Pj. Test 1 gli stream **Pj1 - Stream 1** e **Pj1 - Stream 2**;
  - in evidenza **Pj1 - Stream 1** e **Pj. Test 2**.
- Solo struttura: nessun elemento, nota o audio.
- Si crea **una volta sola** (impostazione `starter_example_done`): se l'utente lo elimina non ricompare; su un archivio già in uso non si crea mai.
- Anche gli **stream** si possono fissare in "In evidenza" (tasto destro › Fissa in alto), come progetti, categorie e tag.
- Il nome del secondo stream segue la richiesta dell'utente ("PJ2 - Stream 2" letto come secondo stream di Pj. Test 1, quindi "Pj1 - Stream 2").

## Alternative scartate
- **Nessun esempio:** più pulito, ma chi parte non vede la struttura. La guida e il tour la spiegano, ma l'esempio la mostra.
- **Un archivio dimostrativo con contenuti** (come quello degli screenshot): troppi dati finti da cancellare in un archivio di lavoro.

## Conseguenze
- Chi non vuole l'esempio lo elimina con un clic sul cliente; chi vuole, lo rinomina e lo usa.
- L'archivio dimostrativo con contenuti inventati (ADR-0061) resta solo nella build Debug, per gli screenshot: non è nell'app distribuita.
