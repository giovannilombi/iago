# ADR-0071 — Sintesi e proposte fatte da Claude

- Stato: accettato
- Data: 2026-10-27
- Riferimenti: ADR-0043 (server MCP), ADR-0044 e ADR-0047 (scritture con anteprima), ADR-0054 (sintesi per categoria), ADR-0009 (il motore propone, l'utente conferma), ADR-0058 (niente esce senza la scelta dell'utente), ADR-0070 (provenienza); indicazioni dell'utente del 2026-10-27

## Contesto
- Sui Mac con poca memoria il motore locale è lento o non basta; Claude scrive sintesi e proposte di qualità più alta.
- Con MCP è sempre Claude a chiamare IAGO: IAGO non può delegargli un lavoro da solo. Delegare significa che l'utente apre Claude e glielo chiede.
- Il rischio maggiore è che Claude lavori sull'elemento sbagliato, o non lo trovi, e che l'utente si frustri.
- ADR-0054 dava a Claude le sintesi in sola lettura.

## Decisione
- **Trovare l'elemento:**
  - nella scheda, **Copia per Claude…** copia il riferimento (`item_id`, titolo, data, progetto) e una richiesta pronta: *per la sintesi*, *per le proposte*, *solo il riferimento*. Prima di copiare IAGO controlla che il progetto sia consultabile (e scrivibile, se serve) e, se non lo è, lo spiega e lo attiva con un clic;
  - lo strumento `recent_items` elenca gli ultimi elementi di tutti i progetti consultabili, per "la call di ieri"; se i candidati sono più d'uno Claude chiede quale.
- **Sintesi (`set_summary`):** Claude scrive nel **modello della categoria** (`summary_template`) e ogni punto porta la **citazione esatta**. IAGO compone la sintesi con lo stesso codice e gli stessi controlli del motore locale: verifica ogni citazione e collega il punto al suo minuto, scarta i punti senza citazione o con una citazione che non trova, scrive «Non emerso» nelle sezioni vuote. Niente testo libero: le sintesi di Claude hanno la stessa forma e affidabilità di quelle del Mac.
- **Proposte (`propose_suggestions`):** decisioni e attività con citazione verificata, e tag, diventano **proposte in attesa** (ADR-0009), non punti chiave confermati.
- **Come ogni scrittura** (ADR-0047): anteprima con i punti tenuti e scartati, OK dell'utente, conferma; registro accessi; annullabile da Impostazioni › Claude (la sintesi precedente torna com'era, le proposte in attesa spariscono).
- **Convivenza con il motore locale:** la sintesi automatica salta gli elementi che hanno già una sintesi; «Rigenera» chiede conferma prima di sostituire quella di Claude; il motore e Claude non cancellano le proposte in attesa l'uno dell'altro.
- La provenienza («Sintetizzata da Claude», «Consigliata da Claude») segue ADR-0070.

## Conseguenze
- Modifica ADR-0054: Claude può scrivere la sintesi, con i controlli di IAGO.
- Quello che Claude legge va ad Anthropic secondo l'account dell'utente, come già oggi: solo per i progetti che l'utente rende consultabili (ADR-0058).
- Le chiamate di rete non cambiano: è Claude a parlare con Anthropic, IAGO resta un server stdio.
