# ADR-0042 — Titoli proposti dal modello Apple sul Mac

- Stato: accettato
- Data: 2026-10-13
- Riferimenti spec: sez. 4.2 (rete), 3.16 (decisioni), 7.7 (note vocali); FR-150; richiesta utente

## Contesto
Una nota o un passaggio dettato diventa una decisione con titolo e descrizione. Finora il titolo era la prima frase del testo, ripetuta anche nella descrizione, e il risultato era poco leggibile. L'LLM locale arriva con la Fase 3 (localhost). Il modello di Apple Intelligence invece è già nel sistema, gira sul Mac e supporta l'italiano.

## Decisione
- **Generatore:** `IAGOIntelligence/TitleSuggester` usa il framework **Foundation Models**, cioè il modello on-device di Apple Intelligence. Propone un titolo di al massimo 8 parole, nella lingua del testo.
- **Quando interviene:** solo quando un testo lungo (più di 90 caratteri) diventa una decisione. Il testo intero va nella descrizione, e il titolo proposto resta modificabile, segnato con ✨.
- **Ripiego:** se Apple Intelligence è spento o non disponibile, oppure il modello rifiuta, il titolo resta vuoto con la prima frase come suggerimento. Se l'utente lo lascia vuoto, si usa quella.
- **Rete e privacy:**
  - Il modello gira nel processo, sul Mac, senza chiamate di rete, quindi non è un'eccezione alla sez. 4.2 e il controllo automatico resta invariato.
  - Il testo non viene mai scritto nei log.
- **Compatibilità:** `#if canImport(FoundationModels)` e `#available(macOS 26, *)`, così su sistemi precedenti resta solo il ripiego.

## Conseguenze
- Titoli più sintetici senza scaricare modelli e senza servizi a pagamento.
- La qualità dipende dal modello di Apple. Il titolo è sempre una proposta, mai salvato senza che l'utente veda l'editor.
- Lo stesso generatore potrà servire in Fase 3 per titoli di call ed email. I riassunti veri restano all'LLM locale.
