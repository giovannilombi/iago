# ADR-0030 — Cestino con eliminazione automatica dopo 30 giorni

- Stato: accettato (richiesta dell'utente, 2026-10-12)
- Data: 2026-10-12
- Riferimenti spec: FR-60, FR-61, FR-62, sez. 9.3, 17.D

## Contesto
FR-62 prevede l'eliminazione definitiva immediata, senza cestino, e la decisione aperta D lasciava la scelta da fare. L'utente vuole poter recuperare gli errori.

## Decisione
- Eliminando un **elemento** ("Elimina tutto") o un **singolo asset**, IAGO chiede sempre: **Sposta nel cestino** / **Elimina definitivamente** / Annulla.
- Nel cestino (`item.trashed_at`, `asset.trashed_at`) i file restano cifrati con la loro chiave; l'elemento sparisce da elenchi, ricerca ed export e conserva note e segnalibri.
- Vista "Cestino": Ripristina, Elimina definitivamente, Svuota cestino, giorni rimanenti.
- Dopo **30 giorni** dallo spostamento l'eliminazione diventa definitiva (crypto-shredding come sez. 9.3). Controllo all'avvio e una volta al giorno.
- Eccezioni:
  - "Trascrivi ed elimina l'audio" elimina l'audio definitivamente: è la scelta esplicita dell'azione (FR-54);
  - le singole note si eliminano con conferma, senza cestino.

## Conseguenze
- Deroga a FR-62 e chiusura della decisione aperta D.
- Per 30 giorni l'audio "eliminato" esiste ancora (cifrato): chi vuole la cancellazione immediata sceglie "Elimina definitivamente".
- Il cestino è locale: in fase 4 lo stato `trashed_at` non si sincronizza come eliminazione finché non diventa definitivo.
