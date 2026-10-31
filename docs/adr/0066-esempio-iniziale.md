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

## Modifica del 2026-10-31 (1.2.10-beta)
Richiesta dell'utente: un'app appena aperta deve avere progetti di esempio con contenuti, per far vedere subito come si lavora.
- Un archivio nuovo riceve, una sola volta e dopo la scelta della lingua, i **progetti di esempio** di un'agenzia digitale inventata: **Poldo S.p.A.** (Portale clienti headless con gli stream UX/UI e Sviluppo, Design system), **Sanna TheBest s.r.l.** (Rebranding), **Atoms** (Product discovery) e un progetto interno. Dentro ci sono call trascritte e con sintesi, email, documenti, decisioni con la loro storia, attività, rischi, punti da chiarire, richieste, note, presenti e proposte da confermare, su UX, UI, product design, branding e sviluppo headless.
- Tutto è inventato, nella lingua dell'app, datato intorno al giorno di creazione, senza audio. Gli stessi contenuti servono al tour dimostrativo: guida, introduzione e app mostrano lo stesso esempio.
- Gli elementi dell'esempio sono marcati (`capture_meta = example`) e non contano nei primi passi dell'introduzione (ADR-0081).
- **Impostazioni › Progetti › Rimuovi l'esempio** elimina clienti, progetti e contenuti dell'esempio; quello che l'utente ha spostato altrove resta. Non ricompare.
- Supera la scelta «Un archivio dimostrativo con contenuti» scartata sopra: la rimozione con un clic risolve il problema dei dati finti da cancellare. Gli archivi creati prima tengono la vecchia struttura «Cliente Test».
