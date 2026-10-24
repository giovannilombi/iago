# ADR-0057 — Sincronizzazione e condivisione tramite la cartella OneDrive aziendale

- Stato: proposto (bozza per la fase 4; sostituirebbe il backend di ADR-0012). Progetto dettagliato da discutere: `docs/design/sync-cartella-condivisa.md`
- Data: 2026-10-21
- Riferimenti spec: sez. 13 (sync e condivisione), 8.1 (campi di sync, `change_log`); ADR-0012, ADR-0056; proposta di un collega dell'utente, 2026-10-21

## Contesto
- La spec prevede una sincronizzazione cifrata end-to-end su Cloudflare (ADR-0012).
- L'azienda dell'utente ha già un **OneDrive condiviso**, sincronizzato su ogni Mac dall'app di OneDrive. L'utente vuole usarlo, purché:
  - sia **agnostico rispetto a chi crea**;
  - più avanti ci sia una **regia "super admin"** che possa eliminare e gestire per tutti.
- In un dominio aziendale la cifratura è facoltativa.
- Il modello dati è già pronto: tutte le tabelle hanno `created_at`, `updated_at`, `deleted_at`, `version` e `device_id`, e ogni modifica finisce in `change_log`.

## Decisione proposta
### Come funziona
- **Niente database condiviso.** Un file SQLite in una cartella sincronizzata si corrompe. Ogni Mac tiene il proprio archivio e la cartella condivisa contiene solo file **immutabili**.
- **Ogni Mac scrive solo nella propria sottocartella**, così OneDrive non crea mai file in conflitto:
  ```
  OneDrive - Azienda/IAGO/
    spazio.json                        nome, versione del formato, cifratura sì/no
    membri.json                        chi partecipa (nome, email); scritto solo dagli admin
    dispositivi/<device-id>/modifiche/<hlc>.json   lotti di modifiche, append-only
    dispositivi/<device-id>/istantanee/<hlc>.json  stato compatto, ogni tanto
    asset/<sha256>                     trascrizioni, documenti e, se scelto, audio (indirizzati per contenuto)
    Aggiornamenti/                     le release dell'app (ADR-0056)
  ```
- **Pubblicare:** ogni pochi secondi IAGO scrive un lotto con le righe di `change_log` dei progetti condivisi.
- **Ricevere:** IAGO legge i lotti degli altri dispositivi e li applica in modo idempotente.
- **Conflitti:** come la spec, last-writer-wins per campo con un orologio logico ibrido. Sui testi (note, sintesi modificate) si tengono entrambe le versioni e il conflitto viene segnalato.
- **Istantanee:** periodiche, così un Mac nuovo non deve rileggere tutta la storia.
- **Rete:** IAGO non fa nessuna connessione; la rete la gestisce OneDrive. La regola "Rete e privacy" resta valida: il punto 4 di CLAUDE.md diventerebbe "sync tramite cartella condivisa".

### Cosa si condivide
- **Per progetto:** "Condividi con l'azienda" (`sharing_enabled`). Ne fanno parte elementi, note, punti chiave, sintesi e trascrizioni. I progetti non condivisi restano solo sul Mac.
- **Audio:** per spazio, "solo testi" oppure "anche l'audio". L'audio occupa molto: si può scaricare su richiesta.
- **Autore:** ogni riga porta autore e dispositivo. Chiunque nello spazio vede e modifica i progetti condivisi, cioè è agnostico rispetto a chi crea.

### Regia admin (da fare a parte)
- In `membri.json` alcuni membri sono **admin**.
- Un admin può:
  - eliminare per tutti, con un tombstone che ogni Mac applica;
  - archiviare progetti;
  - togliere un membro.
- Le azioni admin sono firmate con una chiave dell'admin, così un file modificato a mano nella cartella non basta per cancellare il lavoro degli altri.

### Cifratura
- **Facoltativa**, decisa alla creazione dello spazio.
- Consigliata almeno per l'audio: una chiave di gruppo, distribuita con un invito e tenuta nel Portachiavi di ogni membro.
- Il contenuto della cartella è comunque già protetto dai permessi di OneDrive dell'azienda.

## Da decidere con l'utente
1. Condivisione **progetto per progetto**, oppure tutto condiviso per default.
2. Audio sì, no o su richiesta.
3. Cifratura: nessuna, solo audio, oppure tutto.
4. Chi è admin, e se la regia admin entra subito o in un secondo momento.
5. Web e mobile: la spec li prevedeva con Cloudflare. Con OneDrive non ci sono. Per ora si rinuncia: solo Mac.

## Conseguenze
- Nessun servizio esterno nuovo, nessun account Cloudflare, nessun costo. Usa l'infrastruttura e i permessi che l'azienda ha già.
- Funziona finché i membri hanno la cartella sincronizzata. I tempi di propagazione sono quelli di OneDrive (secondi o minuti).
- ADR-0012 verrebbe superato per il backend; restano valide le regole su conflitti, tombstone e ricerca lato client.

## Modifica del 2026-10-21 (indicazioni dell'utente)
- **Collaborativo:** un progetto condiviso non è più dell'autore ma dello spazio. Chiunque abbia accesso alla cartella lo usa liberamente.
- **Segno visibile:** l'icona della cartella cloud accanto al progetto, come il logo di Claude.
- **Materiali leggibili anche fuori da IAGO** (Markdown e audio). Nessuna cifratura di default: la protezione è quella della cartella aziendale.
- **Agnostico:** qualunque cartella cloud, non solo OneDrive, perché IAGO sarà distribuito anche fuori dall'azienda.
- **Regia per spazio:** il proprietario e gli admin hanno azioni firmate con chiavi personali; non dipende dall'amministratore di OneDrive.
